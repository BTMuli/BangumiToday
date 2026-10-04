// This file is a part of media_kit
// (https://github.com/media-kit/media-kit).
//
// Copyright © 2021 & onwards, Hitesh Kumar Saini <saini123hitesh@gmail.com>.
// All rights reserved.
// Use of this source code is governed by MIT license that can be found in the
// LICENSE file.

#ifndef VIDEO_OUTPUT_H_
#define VIDEO_OUTPUT_H_

#include <client.h>
#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>
#include <render.h>
#include <render_gl.h>

#include <atomic>
#include <future>
#include <memory>
#include <optional>
#include <unordered_map>
#include <vector>

#include "angle_surface_manager.h"
#include "render_queue.h"
#include "thread_pool.h"

typedef struct _VideoOutputConfiguration {
  std::optional<int64_t> width;
  std::optional<int64_t> height;
  bool enable_hardware_acceleration;

  _VideoOutputConfiguration(std::optional<int64_t> width = std::nullopt,
                            std::optional<int64_t> height = std::nullopt,
                            bool enable_hardware_acceleration = true)
      : width(width),
        height(height),
        enable_hardware_acceleration(enable_hardware_acceleration) {}
} VideoOutputConfiguration;

struct PlaybackGpuTexture {
  int64_t id = 0;
  bool ready = false;
  FlutterDesktopGpuSurfaceDescriptor descriptor{};
  Microsoft::WRL::ComPtr<ID3D11Texture2D> resource;
};

// Unregister callbacks own this store rather than the VideoOutput. They can
// finish after another texture is registered without touching a dead player.
struct PlaybackTextureStore {
  std::mutex mutex;
  bool closed = false;
  int64_t active_id = 0;
  int64_t sampled_id = 0;
  std::unordered_map<int64_t, std::unique_ptr<flutter::TextureVariant>>
      variants;
  std::unordered_map<int64_t, std::shared_ptr<PlaybackGpuTexture>> gpu;
  std::unordered_map<int64_t, std::shared_ptr<FlutterDesktopPixelBuffer>>
      pixels;
  std::unordered_map<int64_t, std::shared_future<void>> unregistering;
};

class VideoOutput {
 public:
  int64_t texture_id() const {
    std::lock_guard<std::mutex> lock(texture_store_->mutex);
    return texture_id_;
  }
  int64_t width() const {
    std::lock_guard<std::mutex> lock(texture_store_->mutex);
    auto gpu = texture_store_->gpu.find(texture_id_);
    if (gpu != texture_store_->gpu.end()) return gpu->second->descriptor.width;
    auto pixels = texture_store_->pixels.find(texture_id_);
    if (pixels != texture_store_->pixels.end()) return pixels->second->width;
    return 1;
  }
  int64_t height() const {
    std::lock_guard<std::mutex> lock(texture_store_->mutex);
    auto gpu = texture_store_->gpu.find(texture_id_);
    if (gpu != texture_store_->gpu.end()) return gpu->second->descriptor.height;
    auto pixels = texture_store_->pixels.find(texture_id_);
    if (pixels != texture_store_->pixels.end()) return pixels->second->height;
    return 1;
  }

  VideoOutput(int64_t handle, VideoOutputConfiguration configuration,
              flutter::PluginRegistrarWindows* registrar,
              ThreadPool* thread_pool_ref);

  ~VideoOutput();

  void SetTextureUpdateCallback(
      std::function<void(int64_t, int64_t, int64_t)> callback);

  void SetSize(std::optional<int64_t> width, std::optional<int64_t> height);

 private:
  void NotifyRender();

  void ProcessRender(bool force);

  void Render();

  void CheckAndResize();

  void Resize(int64_t required_width, int64_t required_height);

  void PublishTexture();

  void RetireSampledTextures();

  std::shared_future<void> UnregisterTexture(int64_t id);

  int64_t GetVideoWidth();

  int64_t GetVideoHeight();

  std::optional<int64_t> width_ = std::nullopt;
  std::optional<int64_t> height_ = std::nullopt;
  VideoOutputConfiguration configuration_ = VideoOutputConfiguration{};

  mpv_handle* handle_ = nullptr;
  mpv_render_context* render_context_ = nullptr;
  int64_t texture_id_ = 0;
  flutter::PluginRegistrarWindows* registrar_ = nullptr;
  ThreadPool* thread_pool_ref_ = nullptr;
  // Set before draining accepted work on the render thread.
  std::atomic<bool> destroyed_{false};
  PlaybackRenderQueue render_queue_;

  std::shared_ptr<PlaybackTextureStore> texture_store_ =
      std::make_shared<PlaybackTextureStore>();
  std::vector<int64_t> retired_texture_ids_;
  bool texture_update_pending_ = false;

  // H/W rendering.

  std::unique_ptr<ANGLESurfaceManager> surface_manager_ = nullptr;

  // S/W rendering.

  std::unique_ptr<uint8_t[]> pixel_buffer_ = nullptr;

  // Notify when the new texture's first frame is ready. Initialization sends
  // its ID with a zero-size rectangle so the Dart controller can start
  // playback.
  std::function<void(int64_t, int64_t, int64_t)> texture_update_callback_ =
      [](int64_t, int64_t, int64_t) {};
};

#endif  // VIDEO_OUTPUT_H_
