// This file is a part of media_kit
// (https://github.com/media-kit/media-kit).
//
// Copyright © 2021 & onwards, Hitesh Kumar Saini <saini123hitesh@gmail.com>.
// All rights reserved.
// Use of this source code is governed by MIT license that can be found in the
// LICENSE file.
#include "angle_surface_manager.h"

#include <chrono>
#include <iostream>
#include <utility>

#include "native_log.h"

namespace {
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
  mutex_ = ::CreateMutex(NULL, FALSE, NULL);
  Create();
  instance_count_++;
}

ANGLESurfaceManager::~ANGLESurfaceManager() {
  CleanUp(true);
  ::ReleaseMutex(mutex_);
  ::CloseHandle(mutex_);
  instance_count_--;
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
    {
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
    // Flutter imports the shared handle and samples it later on its own GPU
    // device. Its release callback only acknowledges the import, not the end
    // of sampling. Never overwrite a resource that has been handed to Flutter.
    D3D11_TEXTURE2D_DESC description{};
    internal_d3d_11_texture_2D_->GetDesc(&description);
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
    ScopedPlaybackTiming submission(sample, PlaybackRenderStage::copy_submit);
    d3d_11_device_context_->CopyResource(snapshot.Get(),
                                        internal_d3d_11_texture_2D_.Get());
    d3d_11_device_context_->End(copy_completion_.Get());
    copy_pending_ = true;
    d3d_11_device_context_->Flush();
    submission.Finish();
    // Flush submits commands asynchronously. Publish only after the copy has
    // completed; on failure the previously completed frame remains available.
    WaitForCopy(sample, PlaybackRenderStage::copy_wait);
    d3d_11_texture_2D_ = std::move(snapshot);
    handle_ = shared_handle;
    frame_available_ = false;
  }
}

void ANGLESurfaceManager::WaitForCopy(PlaybackRenderSample* sample,
                                      PlaybackRenderStage stage) {
  if (!copy_pending_) return;
  ScopedPlaybackTiming timing(sample, stage);
  const auto started = std::chrono::steady_clock::now();
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
      char detail[192]{};
      _snprintf_s(detail, sizeof(detail), _TRUNCATE,
                  "GPU frame copy HRESULT=0x%08lX device_removed=0x%08lX",
                  static_cast<unsigned long>(result),
                  static_cast<unsigned long>(
                      d3d_11_device_->GetDeviceRemovedReason()));
      BangumiNativeGraphicsError(detail);
      throw std::runtime_error("Unable to complete the video frame copy.");
    }
    if (std::chrono::steady_clock::now() - started >=
        std::chrono::milliseconds(100)) {
      char detail[256]{};
      _snprintf_s(
          detail, sizeof(detail), _TRUNCATE,
          "GPU frame copy timed out after 100ms wait_ms=%.2f "
          "polls=%llu size=%dx%d device_removed=0x%08lX",
          PlaybackRenderMilliseconds(PlaybackRenderClock::now() - started),
          polls, width_, height_,
          static_cast<unsigned long>(d3d_11_device_->GetDeviceRemovedReason()));
      BangumiNativeGraphicsError(detail);
      throw std::runtime_error("Timed out copying the video frame.");
    }
    copy_wait_.Wait();
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
    char detail[128]{};
    _snprintf_s(detail, sizeof(detail), _TRUNCATE,
                "eglMakeCurrent failed: EGL error=0x%X", eglGetError());
    BangumiNativeGraphicsError(detail);
    throw std::runtime_error("Unable to activate the video GL context.");
  }
}

void ANGLESurfaceManager::SwapBuffers() { glFinish(); }

void ANGLESurfaceManager::Create(PlaybackRenderSample* sample) {
  ScopedPlaybackTiming timing(sample, PlaybackRenderStage::surface_create);
  CleanUp(false);
  if (!CreateD3DTexture()) {
    throw std::runtime_error("Unable to create Windows Direct3D device.");
    return;
  }
  if (!CreateEGLDisplay()) {
    throw std::runtime_error("Unable to create ANGLE EGL display.");
    return;
  }
  if (!CreateAndBindEGLSurface()) {
    throw std::runtime_error("Unable to create ANGLE EGL surface.");
    return;
  }
  if (internal_handle_ == nullptr) {
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
    if (instance_count_ == 1) {
      eglTerminate(display_);
    }
    display_ = EGL_NO_DISPLAY;
    // Release D3D device & context if the instance is being destroyed.
    copy_completion_.Reset();
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
  internal_handle_ = handle_ = nullptr;
}

bool ANGLESurfaceManager::CreateD3DTexture() {
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
  }

  if (!copy_completion_) {
    const D3D11_QUERY_DESC description{D3D11_QUERY_EVENT, 0};
    auto hr = d3d_11_device_->CreateQuery(&description, &copy_completion_);
    CHECK_HRESULT("ID3D11Device::CreateQuery");
  }

  Microsoft::WRL::ComPtr<IDXGIDevice> dxgi_device = nullptr;
  auto dxgi_device_success = d3d_11_device_->QueryInterface(
      __uuidof(IDXGIDevice), (void**)&dxgi_device);
  if (SUCCEEDED(dxgi_device_success) && dxgi_device != nullptr) {
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
  d3d11_texture2D_desc.MiscFlags = D3D11_RESOURCE_MISC_SHARED;

  // ANGLE draws into one internal texture. Read creates an immutable shared
  // snapshot of each completed frame for Flutter's independent GPU device.

  // Internal.
  auto hr = d3d_11_device_->CreateTexture2D(&d3d11_texture2D_desc, nullptr,
                                            &internal_d3d_11_texture_2D_);
  CHECK_HRESULT("ID3D11Device::CreateTexture2D");
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
      display_, EGL_D3D_TEXTURE_2D_SHARE_HANDLE_ANGLE, internal_handle_,
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
