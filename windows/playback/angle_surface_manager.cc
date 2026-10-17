// This file is a part of media_kit
// (https://github.com/media-kit/media-kit).
//
// Copyright © 2021 & onwards, Hitesh Kumar Saini <saini123hitesh@gmail.com>.
// All rights reserved.
// Use of this source code is governed by MIT license that can be found in the
// LICENSE file.
#include "angle_surface_manager.h"

#include <chrono>
#include <cstring>
#include <iostream>
#include <mutex>
#include <utility>

#include "native_log.h"

namespace {
std::mutex display_lifecycle_mutex;

class MutexLock {
 public:
  explicit MutexLock(HANDLE mutex, DWORD timeout = INFINITE) : mutex_(mutex) {
    const auto result = ::WaitForSingleObject(mutex_, timeout);
    owned_ = result == WAIT_OBJECT_0 || result == WAIT_ABANDONED;
    valid_ = result == WAIT_OBJECT_0;
  }
  ~MutexLock() {
    if (owned_) ::ReleaseMutex(mutex_);
  }
  explicit operator bool() const { return valid_; }

 private:
  HANDLE mutex_;
  bool owned_;
  bool valid_;
};

class D3DContextLock {
 public:
  explicit D3DContextLock(ID3D11Multithread* context) : context_(context) {
    if (context_) context_->Enter();
  }
  ~D3DContextLock() {
    if (context_) context_->Leave();
  }

 private:
  ID3D11Multithread* context_;
};
}  // namespace

#pragma comment(lib, "dxgi.lib")
#pragma comment(lib, "d3d11.lib")

#define FAIL(message)                                              \
  BangumiNativeGraphicsError("ANGLESurfaceManager: " message);     \
  std::cout << "media_kit: ANGLESurfaceManager: Failure: " << message \
            << std::endl;                                             \
  return false

#define CHECK_HRESULT(message) \
  if (FAILED(hr)) {            \
    char detail[128]{};         \
    _snprintf_s(detail, sizeof(detail), _TRUNCATE,                 \
                "ANGLE: %s HRESULT=0x%08lX", message,             \
                static_cast<unsigned long>(hr));                  \
    BangumiNativeGraphicsError(detail);                           \
    FAIL(message);             \
  }

int ANGLESurfaceManager::instance_count_ = 0;

ANGLESurfaceManager::ANGLESurfaceManager(int32_t width, int32_t height)
    : width_(width), height_(height) {
  const std::lock_guard<std::mutex> lifecycle(display_lifecycle_mutex);
  mutex_ = ::CreateMutex(NULL, FALSE, NULL);
  if (!mutex_) throw std::runtime_error("Unable to create the surface mutex.");
  try {
    Create();
    WarmUp();
  } catch (...) {
    CleanUp(true);
    ::CloseHandle(mutex_);
    throw;
  }
}

ANGLESurfaceManager::~ANGLESurfaceManager() {
  const std::lock_guard<std::mutex> lifecycle(display_lifecycle_mutex);
  CleanUp(true);
  ::ReleaseMutex(mutex_);
  ::CloseHandle(mutex_);
}

void ANGLESurfaceManager::SetSize(int32_t width, int32_t height,
                                  PlaybackRenderSample* sample) {
  ScopedPlaybackTiming lock_timing(sample, PlaybackRenderStage::surface_lock);
  MutexLock lock(mutex_);
  if (!lock) throw std::runtime_error("Unable to lock the video surface.");
  lock_timing.Finish();
  if (width == width_ && height == height_) {
    return;
  }
  WaitForCopy(sample);
  width_ = width;
  height_ = height;
  Create(sample);
  frame_available_ = false;
  // Prepare the first snapshot of the new size before its first frame. The
  // allocation and shared-handle setup then happen during the resize instead
  // of extending the frame that first uses the new surface.
  PrepareSnapshot(sample);
}

void ANGLESurfaceManager::Draw(std::function<void()> callback,
                               PlaybackRenderSample* sample) {
  ScopedPlaybackTiming lock_timing(sample, PlaybackRenderStage::surface_lock);
  MutexLock lock(mutex_);
  if (!lock) throw std::runtime_error("Unable to lock the video surface.");
  lock_timing.Finish();
  // A timed-out copy must finish before ANGLE can overwrite its source.
  WaitForCopy(sample);
  MakeCurrent(true, sample);
  try {
    {
      ScopedPlaybackTiming timing(sample, PlaybackRenderStage::mpv_render);
      callback();
    }
    // The snapshot is normally prepared after the previous publish or by a
    // resize. Allocate here only as a fallback, while ANGLE's submitted GPU
    // work can still run, rather than after its completion wait.
    {
      ScopedPlaybackTiming timing(sample, PlaybackRenderStage::swap);
      glFlush();
    }
    PrepareSnapshot(sample);
    if (!uses_angle_device_) {
      ScopedPlaybackTiming timing(sample, PlaybackRenderStage::swap);
      SwapBuffers();
    }
    frame_available_ = true;
  } catch (...) {
    MakeCurrent(false, sample);
    throw;
  }
  MakeCurrent(false, sample);
}

void ANGLESurfaceManager::Read(PlaybackRenderSample* sample) {
  ScopedPlaybackTiming lock_timing(sample, PlaybackRenderStage::surface_lock);
  MutexLock lock(mutex_);
  if (!lock) throw std::runtime_error("Unable to lock the video surface.");
  lock_timing.Finish();
  if (frame_available_ && d3d_11_device_context_ != nullptr) {
    WaitForCopy(sample);
    ScopedPlaybackTiming submission(sample, PlaybackRenderStage::copy_submit);
    {
      const D3DContextLock context_lock(shared_context_lock_.Get());
      // On the unified path glFlush submitted the draw on this very context.
      // This query therefore covers rendering AND copying with one CPU wait.
      d3d_11_device_context_->CopyResource(prepared_snapshot_.Get(),
                                          internal_d3d_11_texture_2D_.Get());
      d3d_11_device_context_->End(copy_completion_.Get());
      copy_pending_ = true;
      copy_wait_.Flush(d3d_11_device_context_);
    }
    submission.Finish();
    // Flush submits commands asynchronously. Publish only after the copy has
    // completed; on failure the previously completed frame remains available.
    WaitForCopy(sample, PlaybackRenderStage::copy_wait);
    d3d_11_texture_2D_ = std::move(prepared_snapshot_);
    handle_ = prepared_handle_;
    prepared_handle_ = nullptr;
    frame_available_ = false;
  }
}

void ANGLESurfaceManager::WarmUp() {
  const auto started = PlaybackRenderClock::now();
  PrepareSnapshot();
  // Run one complete copy/query round-trip at the initial size. This pays the
  // driver's copy and shared-context setup while the player is still opening
  // media, so the first visible frame does not. The copied content is never
  // published.
  {
    const D3DContextLock context_lock(shared_context_lock_.Get());
    d3d_11_device_context_->CopyResource(prepared_snapshot_.Get(),
                                         internal_d3d_11_texture_2D_.Get());
    d3d_11_device_context_->End(copy_completion_.Get());
    copy_pending_ = true;
    copy_wait_.Flush(d3d_11_device_context_);
  }
  WaitForCopy();
  char message[128]{};
  _snprintf_s(message, sizeof(message), _TRUNCATE,
              "ANGLESurfaceManager warm-up copy elapsed_ms=%.2f size=%dx%d",
              PlaybackRenderMilliseconds(PlaybackRenderClock::now() - started),
              width_, height_);
  BangumiNativeLog(message);
}

bool ANGLESurfaceManager::PrepareSnapshot(PlaybackRenderSample* sample) {
  // Flutter imports the shared handle and samples it later on its own GPU
  // device. Its release callback only acknowledges the import, not the end
  // of sampling. Never overwrite a resource that has been handed to Flutter.
  if (prepared_snapshot_) return false;
  if (!internal_d3d_11_texture_2D_ || !d3d_11_device_)
    throw std::runtime_error("Unable to prepare the video frame snapshot.");
  D3D11_TEXTURE2D_DESC description{};
  internal_d3d_11_texture_2D_->GetDesc(&description);
  // Only the published immutable snapshot needs a shared handle for Flutter.
  description.MiscFlags = D3D11_RESOURCE_MISC_SHARED;
  Microsoft::WRL::ComPtr<ID3D11Texture2D> snapshot;
  ScopedPlaybackTiming allocation(sample, PlaybackRenderStage::snapshot);
  auto hr = d3d_11_device_->CreateTexture2D(&description, nullptr, &snapshot);
  if (FAILED(hr)) {
    char detail[128]{};
    _snprintf_s(detail, sizeof(detail), _TRUNCATE,
                "CreateTexture2D snapshot HRESULT=0x%08lX",
                static_cast<unsigned long>(hr));
    BangumiNativeGraphicsError(detail);
    throw std::runtime_error("Unable to create the video frame snapshot.");
  }
  allocation.Finish();
  ScopedPlaybackTiming sharing(sample, PlaybackRenderStage::share);
  Microsoft::WRL::ComPtr<IDXGIResource> resource;
  HANDLE shared_handle = nullptr;
  hr = snapshot.As(&resource);
  if (SUCCEEDED(hr)) hr = resource->GetSharedHandle(&shared_handle);
  if (FAILED(hr) || shared_handle == nullptr) {
    char detail[128]{};
    _snprintf_s(detail, sizeof(detail), _TRUNCATE,
                "GetSharedHandle snapshot HRESULT=0x%08lX",
                static_cast<unsigned long>(hr));
    BangumiNativeGraphicsError(detail);
    throw std::runtime_error("Unable to share the video frame snapshot.");
  }
  sharing.Finish();
  prepared_snapshot_ = std::move(snapshot);
  prepared_handle_ = shared_handle;
  return true;
}

void ANGLESurfaceManager::WaitForCopy(PlaybackRenderSample* sample,
                                      PlaybackRenderStage stage) {
  if (!copy_pending_) return;
  ScopedPlaybackTiming timing(sample, stage);
  const auto started = std::chrono::steady_clock::now();
  // The shared-context query includes rendering, which could previously spend
  // an unbounded time in glFinish. Keep a bounded whole-frame deadline without
  // mistaking a >100 ms render for a copy timeout. The legacy copy stays 100 ms.
  const auto timeout = std::chrono::milliseconds(uses_angle_device_ ? 1000 : 100);
  uint64_t polls = 0;
  for (;;) {
    ++polls;
    if (sample) ++sample->gpu_polls;
    const auto result = d3d_11_device_context_->GetData(
        copy_completion_.Get(), nullptr, 0, D3D11_ASYNC_GETDATA_DONOTFLUSH);
    if (result == S_OK) {
      copy_pending_ = false;
      return;
    }
    if (result != S_FALSE) {
      const auto removed = d3d_11_device_->GetDeviceRemovedReason();
      char detail[192]{};
      _snprintf_s(detail, sizeof(detail), _TRUNCATE,
                  "GPU frame copy HRESULT=0x%08lX device_removed=0x%08lX",
                  static_cast<unsigned long>(result),
                  static_cast<unsigned long>(
                      removed));
      BangumiNativeGraphicsError(detail);
      if (FAILED(removed)) {
        copy_pending_ = false;
        throw PlaybackGraphicsDeviceLost(detail);
      }
      throw std::runtime_error("Unable to complete the video frame copy.");
    }
    const auto elapsed = std::chrono::steady_clock::now() - started;
    if (elapsed >= timeout) {
      const auto removed = d3d_11_device_->GetDeviceRemovedReason();
      char detail[256]{};
      _snprintf_s(
          detail, sizeof(detail), _TRUNCATE,
          "GPU frame completion timed out after %lldms wait_ms=%.2f "
          "polls=%llu size=%dx%d device_removed=0x%08lX",
          static_cast<long long>(timeout.count()),
          PlaybackRenderMilliseconds(PlaybackRenderClock::now() - started),
          polls, width_, height_,
          static_cast<unsigned long>(removed));
      BangumiNativeGraphicsError(detail);
      if (FAILED(removed)) {
        copy_pending_ = false;
        throw PlaybackGraphicsDeviceLost(detail);
      }
      throw std::runtime_error("Timed out completing the video frame.");
    }
    const auto remaining = std::chrono::duration_cast<std::chrono::milliseconds>(
        timeout - elapsed).count();
    // Recheck device removal at least every 100 ms, even on a long render.
    copy_wait_.Wait(static_cast<DWORD>(remaining > 100 ? 100
                                      : remaining > 0 ? remaining : 1));
  }
}

void ANGLESurfaceManager::MakeCurrent(bool value,
                                      PlaybackRenderSample* sample) {
  ScopedPlaybackTiming timing(sample, PlaybackRenderStage::context);
  const auto result =
      value ? eglMakeCurrent(display_, surface_, surface_, context_)
            : eglMakeCurrent(display_, EGL_NO_SURFACE, EGL_NO_SURFACE,
                             EGL_NO_CONTEXT);
  if (result == EGL_FALSE) {
    const auto egl_error = eglGetError();
    const auto removed =
        d3d_11_device_ ? d3d_11_device_->GetDeviceRemovedReason() : S_OK;
    char detail[192]{};
    _snprintf_s(detail, sizeof(detail), _TRUNCATE,
                "eglMakeCurrent failed: EGL error=0x%X device_removed=0x%08lX",
                egl_error, static_cast<unsigned long>(removed));
    BangumiNativeGraphicsError(detail);
    if (egl_error == EGL_CONTEXT_LOST || FAILED(removed)) {
      throw PlaybackGraphicsDeviceLost(detail);
    }
    throw std::runtime_error("Unable to activate the video GL context.");
  }
}

void ANGLESurfaceManager::SwapBuffers() { glFinish(); }

void ANGLESurfaceManager::Create(PlaybackRenderSample* sample) {
  ScopedPlaybackTiming timing(sample, PlaybackRenderStage::surface_create);
  CleanUp(false);
  if (!CreateD3DDevice()) {
    throw std::runtime_error("Unable to create Windows Direct3D device.");
  }
  if (!CreateEGLDisplay()) {
    throw std::runtime_error("Unable to create ANGLE EGL display.");
    return;
  }
  if (!CreateD3DTexture()) {
    throw std::runtime_error("Unable to create Windows Direct3D device.");
    return;
  }
  if (!CreateAndBindEGLSurface()) {
    throw std::runtime_error("Unable to create ANGLE EGL surface.");
    return;
  }
  if (!uses_angle_device_ && internal_handle_ == nullptr) {
    throw std::runtime_error("Unable to retrieve Direct3D shared HANDLE.");
    return;
  }
}

void ANGLESurfaceManager::CleanUp(bool release_context) {
  if (display_ != EGL_NO_DISPLAY) {
    eglMakeCurrent(display_, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT);
  }
  if (release_context) {
    if (display_ != EGL_NO_DISPLAY && context_ != EGL_NO_CONTEXT) {
      eglDestroyContext(display_, context_);
      context_ = EGL_NO_CONTEXT;
    }
    if (surface_ != EGL_NO_SURFACE) {
      eglDestroySurface(display_, surface_);
      surface_ = EGL_NO_SURFACE;
    }
    if (egl_device_ != EGL_NO_DEVICE_EXT) {
      eglTerminate(display_);
      release_egl_device_(egl_device_);
      egl_device_ = EGL_NO_DEVICE_EXT;
      release_egl_device_ = nullptr;
    } else if (registered_default_display_) {
      registered_default_display_ = false;
      if (--instance_count_ == 0) eglTerminate(display_);
    }
    display_ = EGL_NO_DISPLAY;
    // Release D3D device & context if the instance is being destroyed.
    copy_completion_.Reset();
    copy_wait_.SetContext(nullptr);
    shared_context_lock_.Reset();
    uses_angle_device_ = false;
    if (d3d_11_device_context_) {
      d3d_11_device_context_->Release();
      d3d_11_device_context_ = nullptr;
    }
    if (d3d_11_device_) {
      d3d_11_device_->Release();
      d3d_11_device_ = nullptr;
    }
  } else {
    // Detach the old draw surface before recreating it in the same context.
    if (display_ != EGL_NO_DISPLAY && surface_ != EGL_NO_SURFACE) {
      eglDestroySurface(display_, surface_);
    }
    surface_ = EGL_NO_SURFACE;
  }
  // Release D3D 11 texture(s).
  internal_d3d_11_texture_2D_.Reset();
  d3d_11_texture_2D_.Reset();
  prepared_snapshot_.Reset();
  prepared_handle_ = nullptr;
  internal_handle_ = handle_ = nullptr;
}

bool ANGLESurfaceManager::CreateDeviceDisplay() {
  const auto extensions = eglQueryString(EGL_NO_DISPLAY, EGL_EXTENSIONS);
  if (!extensions || !std::strstr(extensions, "EGL_ANGLE_device_creation_d3d11") ||
      !std::strstr(extensions, "EGL_EXT_platform_device") ||
      d3d_11_device_->GetFeatureLevel() < D3D_FEATURE_LEVEL_10_0) {
    eglGetError();
    return false;
  }
  const auto create_device = reinterpret_cast<PFNEGLCREATEDEVICEANGLEPROC>(
      eglGetProcAddress("eglCreateDeviceANGLE"));
  const auto release_device = reinterpret_cast<PFNEGLRELEASEDEVICEANGLEPROC>(
      eglGetProcAddress("eglReleaseDeviceANGLE"));
  const auto get_display = reinterpret_cast<PFNEGLGETPLATFORMDISPLAYEXTPROC>(
      eglGetProcAddress("eglGetPlatformDisplayEXT"));
  const auto query_display = reinterpret_cast<PFNEGLQUERYDISPLAYATTRIBEXTPROC>(
      eglGetProcAddress("eglQueryDisplayAttribEXT"));
  const auto query_device = reinterpret_cast<PFNEGLQUERYDEVICEATTRIBEXTPROC>(
      eglGetProcAddress("eglQueryDeviceAttribEXT"));
  if (!create_device || !release_device || !get_display || !query_display ||
      !query_device)
    return false;
  Microsoft::WRL::ComPtr<ID3D11Multithread> multithread;
  if (FAILED(d3d_11_device_context_->QueryInterface(IID_PPV_ARGS(&multithread))))
    return false;
  multithread->SetMultithreadProtected(TRUE);
  if (!multithread->GetMultithreadProtected()) return false;

  // A private EGL device gives each player its own ANGLE renderer. Reusing the
  // process-wide default renderer would expose its state cache to other workers.
  const auto device = create_device(EGL_D3D11_DEVICE_ANGLE, d3d_11_device_, nullptr);
  if (device == EGL_NO_DEVICE_EXT) {
    eglGetError();
    return false;
  }
  const auto display = get_display(EGL_PLATFORM_DEVICE_EXT, device, nullptr);
  const bool initialized = display != EGL_NO_DISPLAY && eglInitialize(display, 0, 0);
  const auto display_extensions = initialized
      ? eglQueryString(display, EGL_EXTENSIONS) : nullptr;
  EGLAttrib actual_device = 0;
  EGLAttrib native_device = 0;
  if (!display_extensions ||
      !std::strstr(display_extensions, "EGL_ANGLE_d3d_texture_client_buffer") ||
      !query_display(display, EGL_DEVICE_EXT, &actual_device) ||
      !query_device(reinterpret_cast<EGLDeviceEXT>(actual_device),
                    EGL_D3D11_DEVICE_ANGLE, &native_device) ||
      reinterpret_cast<ID3D11Device*>(native_device) != d3d_11_device_) {
    if (display != EGL_NO_DISPLAY) eglTerminate(display);
    release_device(device);
    eglGetError();
    return false;
  }
  display_ = display;
  egl_device_ = device;
  release_egl_device_ = release_device;
  shared_context_lock_ = std::move(multithread);
  uses_angle_device_ = true;
  BangumiNativeLog("ANGLE rendering and snapshots share one D3D11 context");
  return true;
}

bool ANGLESurfaceManager::CreateD3DDevice() {
  if (d3d_11_device_ == nullptr) {
    // NOTE: Not enabling Feature Level 12. It crashes directly on Windows 7.
    const auto feature_levels = {
        D3D_FEATURE_LEVEL_11_0,
        D3D_FEATURE_LEVEL_10_1,
        D3D_FEATURE_LEVEL_10_0,
        D3D_FEATURE_LEVEL_9_3,
    };

    IDXGIAdapter* adapter = nullptr;
    D3D_DRIVER_TYPE driver_type = D3D_DRIVER_TYPE_UNKNOWN;

    // NOTE: Automatically selecting adapter on Windows 10 RTM or greater.
    if (Utils::IsWindows10RTMOrGreater()) {
      adapter = NULL;
      driver_type = D3D_DRIVER_TYPE_HARDWARE;
    } else {
      IDXGIFactory* dxgi = nullptr;
      ::CreateDXGIFactory(__uuidof(IDXGIFactory), (void**)&dxgi);
      // As far as my experience goes, this is the safest approach. Passing NULL
      // (so-called default) seems to cause issues on Windows 7 or maybe some
      // older graphics drivers. First adapter is the default.
      // D3D_DRIVER_TYPE_UNKNOWN| must be passed with manual adapter selection.
      dxgi->EnumAdapters(0, &adapter);
      dxgi->Release();
    }

    auto hr = ::D3D11CreateDevice(
        adapter, driver_type, 0, 0, feature_levels.begin(),
        static_cast<UINT>(feature_levels.size()), D3D11_SDK_VERSION,
        &d3d_11_device_, 0, &d3d_11_device_context_);
    CHECK_HRESULT("D3D11CreateDevice");
    copy_wait_.SetContext(d3d_11_device_context_);
  }
  return true;
}

bool ANGLESurfaceManager::CreateD3DTexture() {
  if (!copy_completion_) {
    const D3D11_QUERY_DESC description{D3D11_QUERY_EVENT, 0};
    auto hr = d3d_11_device_->CreateQuery(&description, &copy_completion_);
    CHECK_HRESULT("ID3D11Device::CreateQuery");
  }

  Microsoft::WRL::ComPtr<IDXGIDevice> dxgi_device = nullptr;
  auto dxgi_device_success = d3d_11_device_->QueryInterface(
      __uuidof(IDXGIDevice), (void**)&dxgi_device);
  if (SUCCEEDED(dxgi_device_success) && dxgi_device != nullptr) {
    if (!uses_angle_device_)
      dxgi_device->SetGPUThreadPriority(5);  // Must be in interval [-7, 7].
    Microsoft::WRL::ComPtr<IDXGIAdapter> adapter;
    DXGI_ADAPTER_DESC description{};
    if (SUCCEEDED(dxgi_device->GetAdapter(&adapter)) &&
        SUCCEEDED(adapter->GetDesc(&description))) {
      char name[512]{};
      WideCharToMultiByte(CP_UTF8, 0, description.Description, -1, name,
                          sizeof(name), nullptr, nullptr);
      char detail[768]{};
      _snprintf_s(detail, sizeof(detail), _TRUNCATE,
                  "ANGLE GPU=%s vendor=0x%X device=0x%X VRAM_MB=%llu", name,
                  description.VendorId, description.DeviceId,
                  static_cast<unsigned long long>(
                      description.DedicatedVideoMemory / (1024 * 1024)));
      BangumiNativeLog(detail);
    }
  }

  auto level = d3d_11_device_->GetFeatureLevel();
  char device_info[128]{};
  _snprintf_s(device_info, sizeof(device_info), _TRUNCATE,
              "ANGLE Direct3D feature level=0x%X", static_cast<unsigned>(level));
  BangumiNativeLog(device_info);
  std::cout << "media_kit: ANGLESurfaceManager: Direct3D Feature Level: "
            << (((unsigned)level) >> 12) << "_"
            << ((((unsigned)level) >> 8) & 0xf) << std::endl;
  auto d3d11_texture2D_desc = D3D11_TEXTURE2D_DESC{0};
  d3d11_texture2D_desc.Width = width_;
  d3d11_texture2D_desc.Height = height_;
  d3d11_texture2D_desc.Format = DXGI_FORMAT_B8G8R8A8_UNORM;
  d3d11_texture2D_desc.MipLevels = 1;
  d3d11_texture2D_desc.ArraySize = 1;
  d3d11_texture2D_desc.SampleDesc.Count = 1;
  d3d11_texture2D_desc.SampleDesc.Quality = 0;
  d3d11_texture2D_desc.Usage = D3D11_USAGE_DEFAULT;
  d3d11_texture2D_desc.BindFlags =
      D3D11_BIND_RENDER_TARGET | D3D11_BIND_SHADER_RESOURCE;
  d3d11_texture2D_desc.CPUAccessFlags = 0;
  d3d11_texture2D_desc.MiscFlags =
      uses_angle_device_ ? 0 : D3D11_RESOURCE_MISC_SHARED;

  // ANGLE draws into one internal texture. Read creates an immutable shared
  // snapshot of each completed frame for Flutter's independent GPU device.

  // Internal.
  auto hr = d3d_11_device_->CreateTexture2D(&d3d11_texture2D_desc, nullptr,
                                            &internal_d3d_11_texture_2D_);
  CHECK_HRESULT("ID3D11Device::CreateTexture2D");
  if (uses_angle_device_) return true;
  auto resource = Microsoft::WRL::ComPtr<IDXGIResource>{};
  hr = internal_d3d_11_texture_2D_.As(&resource);
  CHECK_HRESULT("ID3D11Texture2D::As");
  // Retrieve the shared |HANDLE| for interop.
  hr = resource->GetSharedHandle(&internal_handle_);
  CHECK_HRESULT("IDXGIResource::GetSharedHandle");

  return true;
}

bool ANGLESurfaceManager::CreateEGLDisplay() {
  if (display_ == EGL_NO_DISPLAY) {
    if (CreateDeviceDisplay()) return true;
    auto eglGetPlatformDisplayEXT =
        reinterpret_cast<PFNEGLGETPLATFORMDISPLAYEXTPROC>(
            eglGetProcAddress("eglGetPlatformDisplayEXT"));
    if (eglGetPlatformDisplayEXT) {
      display_ = eglGetPlatformDisplayEXT(EGL_PLATFORM_ANGLE_ANGLE,
                                          EGL_DEFAULT_DISPLAY,
                                          kD3D11DisplayAttributes);
      if (eglInitialize(display_, 0, 0) == EGL_FALSE) {
        display_ = eglGetPlatformDisplayEXT(EGL_PLATFORM_ANGLE_ANGLE,
                                            EGL_DEFAULT_DISPLAY,
                                            kD3D11_9_3DisplayAttributes);
        if (eglInitialize(display_, 0, 0) == EGL_FALSE) {
          display_ = eglGetPlatformDisplayEXT(EGL_PLATFORM_ANGLE_ANGLE,
                                              EGL_DEFAULT_DISPLAY,
                                              kD3D9DisplayAttributes);
          if (eglInitialize(display_, 0, 0) == EGL_FALSE) {
            display_ = eglGetPlatformDisplayEXT(EGL_PLATFORM_ANGLE_ANGLE,
                                                EGL_DEFAULT_DISPLAY,
                                                kWrapDisplayAttributes);
            if (eglInitialize(display_, 0, 0) == EGL_FALSE) {
              FAIL("eglGetPlatformDisplayEXT");
            }
          }
        }
      }
    } else {
      FAIL("eglGetProcAddress");
    }
    registered_default_display_ = true;
    instance_count_++;
  }
  return true;
}

bool ANGLESurfaceManager::CreateAndBindEGLSurface() {
  // Do not create |context_| again, likely due to |Resize|.
  if (context_ == EGL_NO_CONTEXT) {
    // First time from the constructor itself.
    auto count = 0;
    auto result = eglChooseConfig(display_, kEGLConfigurationAttributes,
                                  &config_, 1, &count);
    if (result == EGL_FALSE || count == 0) {
      FAIL("eglChooseConfig");
    }
    context_ = eglCreateContext(display_, config_, EGL_NO_CONTEXT,
                                kEGLContextAttributes);
    if (context_ == EGL_NO_CONTEXT) {
      FAIL("eglCreateContext");
    }
  }
  EGLint buffer_attributes[] = {
      EGL_WIDTH,          width_,         EGL_HEIGHT,         height_,
      EGL_TEXTURE_TARGET, EGL_TEXTURE_2D, EGL_TEXTURE_FORMAT, EGL_TEXTURE_RGBA,
      EGL_NONE,
  };
  surface_ = eglCreatePbufferFromClientBuffer(
      display_,
      uses_angle_device_ ? EGL_D3D_TEXTURE_ANGLE
                         : EGL_D3D_TEXTURE_2D_SHARE_HANDLE_ANGLE,
      uses_angle_device_
          ? reinterpret_cast<EGLClientBuffer>(internal_d3d_11_texture_2D_.Get())
          : internal_handle_,
      config_, buffer_attributes);
  if (surface_ == EGL_NO_SURFACE) {
    FAIL("eglCreatePbufferFromClientBuffer");
  }
  // mpv renders directly to the pbuffer's default framebuffer. Binding this
  // same pbuffer as a sampled GL texture is unnecessary and can fail while it
  // is current. Verify the new draw surface instead.
  if (eglMakeCurrent(display_, surface_, surface_, context_) == EGL_FALSE) {
    FAIL("eglMakeCurrent");
  }
  return true;
}
