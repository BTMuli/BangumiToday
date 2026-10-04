// This file is a part of media_kit
// (https://github.com/media-kit/media-kit).
//
// Copyright © 2021 & onwards, Hitesh Kumar Saini <saini123hitesh@gmail.com>.
// All rights reserved.
// Use of this source code is governed by MIT license that can be found in the
// LICENSE file.

#include "video_output.h"

#include <algorithm>

// Limit the frame size to 1080p in software rendering.
// This is for performance reasons & to avoid allocating too much memory.
#define SW_RENDERING_MAX_WIDTH 1920
#define SW_RENDERING_MAX_HEIGHT 1080
#define SW_RENDERING_PIXEL_BUFFER_SIZE \
  (SW_RENDERING_MAX_WIDTH) * (SW_RENDERING_MAX_HEIGHT) * (4)

VideoOutput::VideoOutput(int64_t handle, VideoOutputConfiguration configuration,
                         flutter::PluginRegistrarWindows* registrar,
                         ThreadPool* thread_pool_ref)
    : handle_(reinterpret_cast<mpv_handle*>(handle)),
      width_(configuration.width),
      height_(configuration.height),
      configuration_(configuration),
      registrar_(registrar),
      thread_pool_ref_(thread_pool_ref),
      render_queue_(
          [this](std::function<void()> task) {
            thread_pool_ref_->Post(std::move(task));
          },
          [this](bool force) { ProcessRender(force); }) {
  // The constructor must be invoked through the thread pool, because
  // |ANGLESurfaceManager| & libmpv render context creation can conflict with
  // the existing |Render| or |Resize| calls from another |VideoOutput|
  // instances (which will result in access violation).
  auto future = thread_pool_ref_->Post([&]() {
    mpv_set_option_string(handle_, "video-sync", "audio");
    mpv_set_option_string(handle_, "video-timing-offset", "0");
    // First try to initialize video playback with hardware acceleration &
    // |ANGLESurfaceManager|, use S/W API as fallback.
    auto is_hardware_acceleration_enabled = false;
    // Attempt to use H/W rendering.
    if (configuration.enable_hardware_acceleration) {
      try {
        // OpenGL context needs to be set before |mpv_render_context_create|.
        surface_manager_ = std::make_unique<ANGLESurfaceManager>(
            static_cast<int32_t>(width_.value_or(1)),
            static_cast<int32_t>(height_.value_or(1)));
        surface_manager_->MakeCurrent(true);
        Resize(width_.value_or(1), height_.value_or(1));
        mpv_opengl_init_params gl_init_params{
            [](auto, auto name) {
              return reinterpret_cast<void*>(eglGetProcAddress(name));
            },
            nullptr,
        };
        mpv_render_param params[] = {
            {MPV_RENDER_PARAM_API_TYPE, MPV_RENDER_API_TYPE_OPENGL},
            {MPV_RENDER_PARAM_OPENGL_INIT_PARAMS, &gl_init_params},
            {MPV_RENDER_PARAM_INVALID, nullptr},
        };
        // Create render context.
        if (mpv_render_context_create(&render_context_, handle_, params) == 0) {
          mpv_render_context_set_update_callback(
              render_context_,
              [](void* context) {
                // Notify Flutter that a new frame is available. The actual
                // rendering will take place in the |Render| method, which will
                // be called by Flutter on the render thread.
                auto that = reinterpret_cast<VideoOutput*>(context);
                that->NotifyRender();
              },
              reinterpret_cast<void*>(this));
          // Set flag to true, indicating that H/W rendering is supported.
          is_hardware_acceleration_enabled = true;
          std::cout << "media_kit: VideoOutput: Using H/W rendering."
                    << std::endl;
        }
      } catch (...) {
        // Do nothing.
        // Likely received an |std::runtime_error| from |ANGLESurfaceManager|,
        // which indicates that H/W rendering is not supported.
      }
    }
    if (!is_hardware_acceleration_enabled) {
      surface_manager_.reset();
      std::cout << "media_kit: VideoOutput: Using S/W rendering." << std::endl;
      // Allocate a "large enough" buffer ahead of time.
      pixel_buffer_ =
          std::make_unique<uint8_t[]>(SW_RENDERING_PIXEL_BUFFER_SIZE);
      Resize(width_.value_or(1), height_.value_or(1));
      mpv_render_param params[] = {
          {MPV_RENDER_PARAM_API_TYPE, MPV_RENDER_API_TYPE_SW},
          {MPV_RENDER_PARAM_INVALID, nullptr},
      };
      if (mpv_render_context_create(&render_context_, handle_, params) == 0) {
        mpv_render_context_set_update_callback(
            render_context_,
            [](void* context) {
              // Notify Flutter that a new frame is available. The actual
              // rendering will take place in the |Render| method, which will be
              // called by Flutter on the render thread.
              auto that = reinterpret_cast<VideoOutput*>(context);
              that->NotifyRender();
            },
            reinterpret_cast<void*>(this));
      }
    }
  });
  future.wait();
}

VideoOutput::~VideoOutput() {
  render_queue_.Close();
  destroyed_ = true;
  {
    // Finish any texture callback before the render context or surface is
    // freed.
    std::lock_guard<std::mutex> lock(texture_store_->mutex);
    texture_store_->closed = true;
    texture_store_->active_id = 0;
  }
  thread_pool_ref_
      ->Post([this]() {
        if (surface_manager_) surface_manager_->MakeCurrent(true);
        if (render_context_) {
          mpv_render_context_set_update_callback(render_context_, nullptr,
                                                 nullptr);
          mpv_render_context_free(render_context_);
          render_context_ = nullptr;
        }
        if (surface_manager_) surface_manager_->MakeCurrent(false);
      })
      .wait();

  std::vector<int64_t> ids;
  std::vector<std::shared_future<void>> pending;
  {
    std::lock_guard<std::mutex> lock(texture_store_->mutex);
    for (const auto& entry : texture_store_->variants)
      ids.push_back(entry.first);
    for (const auto& entry : texture_store_->unregistering) {
      pending.push_back(entry.second);
    }
  }
  for (auto id : ids) pending.push_back(UnregisterTexture(id));
  for (auto& future : pending) future.wait();
  // EGL creation, rendering and destruction all use the same worker thread.
  thread_pool_ref_
      ->Post([this]() {
        surface_manager_.reset();
        pixel_buffer_.reset();
      })
      .wait();
  std::lock_guard<std::mutex> lock(texture_store_->mutex);
  texture_id_ = 0;
}

void VideoOutput::NotifyRender() { render_queue_.Request(); }

void VideoOutput::ProcessRender(bool force) {
  if (destroyed_ || !render_context_) return;
  // A newly sampled texture also schedules this task, even while paused.
  RetireSampledTextures();
  if (surface_manager_) surface_manager_->MakeCurrent(true);
  const auto updates = mpv_render_context_update(render_context_);
  if (surface_manager_) surface_manager_->MakeCurrent(false);
  if (!force && !(updates & MPV_RENDER_UPDATE_FRAME)) return;
  CheckAndResize();
  Render();
}

void VideoOutput::Render() {
  if (destroyed_ || !texture_id_) return;
  // video-timing-offset is zero. Do not wait for the core's presentation signal
  // while holding the surface mutex needed by Flutter's texture callback.
  int block_for_target_time = 0;
  if (surface_manager_) {
    surface_manager_->Draw([&]() {
      mpv_opengl_fbo fbo{0, surface_manager_->width(),
                         surface_manager_->height(), 0};
      mpv_render_param params[]{
          {MPV_RENDER_PARAM_OPENGL_FBO, &fbo},
          {MPV_RENDER_PARAM_BLOCK_FOR_TARGET_TIME, &block_for_target_time},
          {MPV_RENDER_PARAM_INVALID, nullptr},
      };
      if (mpv_render_context_render(render_context_, params) < 0) {
        throw std::runtime_error("Unable to render the video frame.");
      }
    });
    // Copy and wait on this worker, never in Flutter's raster callback.
    surface_manager_->Read();
    auto frame = std::make_shared<PlaybackGpuFrame>();
    frame->resource = surface_manager_->texture();
    auto& descriptor = frame->descriptor;
    descriptor.struct_size = sizeof(FlutterDesktopGpuSurfaceDescriptor);
    descriptor.handle = surface_manager_->handle();
    descriptor.width = descriptor.visible_width = surface_manager_->width();
    descriptor.height = descriptor.visible_height = surface_manager_->height();
    descriptor.format = kFlutterDesktopPixelFormatBGRA8888;
    descriptor.release_context = frame->resource.Get();
    descriptor.release_callback = [](void* context) {
      static_cast<ID3D11Texture2D*>(context)->Release();
    };
    std::lock_guard<std::mutex> lock(texture_store_->mutex);
    texture_store_->gpu.at(texture_id_)->frame = std::move(frame);
  }
  if (pixel_buffer_) {
    int32_t size[]{static_cast<int32_t>(width()),
                   static_cast<int32_t>(height())};
    size_t pitch = 4 * static_cast<size_t>(size[0]);
    mpv_render_param params[]{
        {MPV_RENDER_PARAM_SW_SIZE, size},
        {MPV_RENDER_PARAM_SW_FORMAT, "rgb0"},
        {MPV_RENDER_PARAM_SW_STRIDE, &pitch},
        {MPV_RENDER_PARAM_SW_POINTER, pixel_buffer_.get()},
        {MPV_RENDER_PARAM_BLOCK_FOR_TARGET_TIME, &block_for_target_time},
        {MPV_RENDER_PARAM_INVALID, nullptr},
    };
    if (mpv_render_context_render(render_context_, params) < 0) {
      throw std::runtime_error("Unable to render the software video frame.");
    }
  }
  PublishTexture();
  registrar_->texture_registrar()->MarkTextureFrameAvailable(texture_id_);
}

void VideoOutput::SetTextureUpdateCallback(
    std::function<void(int64_t, int64_t, int64_t)> callback) {
  thread_pool_ref_
      ->Post([this, callback = std::move(callback)]() {
        texture_update_callback_ = callback;
        // Bootstrap the controller before playback starts. A zero-size
        // rectangle keeps the initial 1x1 allocation out of the displayed
        // video.
        const bool ready = !texture_update_pending_ && GetVideoWidth() > 0 &&
                           GetVideoHeight() > 0;
        texture_update_callback_(texture_id_, ready ? width() : 0,
                                 ready ? height() : 0);
      })
      .wait();
}

void VideoOutput::SetSize(std::optional<int64_t> width,
                          std::optional<int64_t> height) {
  thread_pool_ref_->Post([this, width, height]() {
    if (destroyed_) return;
    width_ = width;
    height_ = height;
    if (pixel_buffer_) {
      if (width_)
        width_ =
            std::clamp(*width_, int64_t{0}, int64_t{SW_RENDERING_MAX_WIDTH});
      if (height_)
        height_ =
            std::clamp(*height_, int64_t{0}, int64_t{SW_RENDERING_MAX_HEIGHT});
    }
    render_queue_.Request(true);
  });
}

void VideoOutput::CheckAndResize() {
  const auto required_width = GetVideoWidth();
  const auto required_height = GetVideoHeight();
  if (required_width < 1 || required_height < 1) return;
  if (required_width == width() && required_height == height()) return;
  Resize(required_width, required_height);
}

void VideoOutput::Resize(int64_t required_width, int64_t required_height) {
  {
    // Old IDs retain their last immutable frame until the new ID is sampled.
    std::lock_guard<std::mutex> lock(texture_store_->mutex);
    texture_store_->active_id = 0;
    if (texture_id_) retired_texture_ids_.push_back(texture_id_);
    texture_id_ = 0;
  }
  std::weak_ptr<PlaybackTextureStore> weak_store = texture_store_;
  if (surface_manager_) {
    surface_manager_->SetSize(static_cast<int32_t>(required_width),
                              static_cast<int32_t>(required_height));
    auto texture = std::make_shared<PlaybackGpuTexture>();
    texture->width = required_width;
    texture->height = required_height;
    auto variant =
        std::make_unique<flutter::TextureVariant>(flutter::GpuSurfaceTexture(
            kFlutterDesktopGpuSurfaceTypeDxgiSharedHandle,
            [this, weak_store, texture](
                auto, auto) -> const FlutterDesktopGpuSurfaceDescriptor* {
              auto store = weak_store.lock();
              if (!store) return nullptr;
              std::lock_guard<std::mutex> lock(store->mutex);
              if (store->closed || !texture->frame) return nullptr;
              if (store->active_id == texture->id) {
                if (store->sampled_id != texture->id) {
                  store->sampled_id = texture->id;
                  render_queue_.Request();
                }
              }
              // Flutter releases this reference after opening the shared
              // handle.
              texture->sampled_frame = texture->frame;
              texture->sampled_frame->resource->AddRef();
              return &texture->sampled_frame->descriptor;
            }));
    const auto id =
        registrar_->texture_registrar()->RegisterTexture(variant.get());
    std::lock_guard<std::mutex> lock(texture_store_->mutex);
    texture->id = id;
    texture_store_->gpu.emplace(id, texture);
    texture_store_->variants.emplace(id, std::move(variant));
    texture_store_->active_id = texture_id_ = id;
  }
  if (pixel_buffer_) {
    auto texture = std::make_shared<FlutterDesktopPixelBuffer>();
    texture->buffer = pixel_buffer_.get();
    texture->width = required_width;
    texture->height = required_height;
    texture->release_callback = [](void*) {};
    auto id = std::make_shared<int64_t>(0);
    auto variant =
        std::make_unique<flutter::TextureVariant>(flutter::PixelBufferTexture(
            [this, weak_store, texture, id](
                auto, auto) -> const FlutterDesktopPixelBuffer* {
              auto store = weak_store.lock();
              if (!store) return nullptr;
              std::lock_guard<std::mutex> lock(store->mutex);
              if (store->closed) return nullptr;
              if (store->active_id == *id && store->sampled_id != *id) {
                store->sampled_id = *id;
                render_queue_.Request();
              }
              return texture.get();
            }));
    const auto registered =
        registrar_->texture_registrar()->RegisterTexture(variant.get());
    std::lock_guard<std::mutex> lock(texture_store_->mutex);
    *id = registered;
    texture_store_->pixels.emplace(registered, texture);
    texture_store_->variants.emplace(registered, std::move(variant));
    texture_store_->active_id = texture_id_ = registered;
  }
  texture_update_pending_ = true;
}

void VideoOutput::PublishTexture() {
  if (!texture_update_pending_) return;
  texture_update_pending_ = false;
  const bool has_video_size = GetVideoWidth() > 0 && GetVideoHeight() > 0;
  texture_update_callback_(texture_id_, has_video_size ? width() : 0,
                           has_video_size ? height() : 0);
}

void VideoOutput::RetireSampledTextures() {
  {
    std::lock_guard<std::mutex> lock(texture_store_->mutex);
    if (texture_store_->sampled_id != texture_id_) return;
  }
  auto retired = std::move(retired_texture_ids_);
  retired_texture_ids_.clear();
  for (auto id : retired) UnregisterTexture(id);
}

std::shared_future<void> VideoOutput::UnregisterTexture(int64_t id) {
  auto store = texture_store_;
  auto promise = std::make_shared<std::promise<void>>();
  auto future = promise->get_future().share();
  {
    std::lock_guard<std::mutex> lock(store->mutex);
    auto existing = store->unregistering.find(id);
    if (existing != store->unregistering.end()) return existing->second;
    store->unregistering.emplace(id, future);
  }
  registrar_->texture_registrar()->UnregisterTexture(
      id, [store, id, promise]() {
        {
          std::lock_guard<std::mutex> lock(store->mutex);
          store->variants.erase(id);
          store->gpu.erase(id);
          store->pixels.erase(id);
          store->unregistering.erase(id);
        }
        promise->set_value();
      });
  return future;
}

int64_t VideoOutput::GetVideoWidth() {
  // NativeVideoController forwards observed source dimensions through SetSize.
  // Synchronous mpv_get_property here can wait on the core that is waiting for
  // this render thread, especially during stop/open or a resolution change.
  return width_.value_or(0);
}

int64_t VideoOutput::GetVideoHeight() { return height_.value_or(0); }
