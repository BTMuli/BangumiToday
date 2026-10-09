// This file is a part of media_kit
// (https://github.com/media-kit/media-kit).
//
// Copyright © 2021 & onwards, Hitesh Kumar Saini <saini123hitesh@gmail.com>.
// All rights reserved.
// Use of this source code is governed by MIT license that can be found in the
// LICENSE file.

#include "video_output.h"

#include <algorithm>

#include "native_log.h"

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
          [this](bool force, double queue_ms, uint64_t requests) {
            ProcessRender(force, queue_ms, requests);
          }) {
  BangumiNativeLog("VideoOutput: creating render context");
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
        // GPU screenshots are dispatched through mpv_render_context_update.
        // This worker never synchronously queries the mpv core, and processes
        // update callbacks even when there is no new video frame.
        int advanced_control = 1;
        mpv_render_param params[] = {
            {MPV_RENDER_PARAM_API_TYPE, MPV_RENDER_API_TYPE_OPENGL},
            {MPV_RENDER_PARAM_OPENGL_INIT_PARAMS, &gl_init_params},
            {MPV_RENDER_PARAM_ADVANCED_CONTROL, &advanced_control},
            {MPV_RENDER_PARAM_INVALID, nullptr},
        };
        // Create render context.
        const auto status =
            mpv_render_context_create(&render_context_, handle_, params);
        if (status == 0) {
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
          BangumiNativeLog("VideoOutput: using hardware rendering");
          std::cout << "media_kit: VideoOutput: Using H/W rendering."
                    << std::endl;
        } else {
          BangumiNativeLog(mpv_error_string(status), true);
        }
      } catch (const std::exception& error) {
        BangumiNativeLog(error.what(), true);
      } catch (...) {
        BangumiNativeLog("Unknown hardware rendering initialization error", true);
      }
    }
    if (!is_hardware_acceleration_enabled) {
      surface_manager_.reset();
      BangumiNativeLog("VideoOutput: falling back to software rendering");
      std::cout << "media_kit: VideoOutput: Using S/W rendering." << std::endl;
      // Allocate a "large enough" buffer ahead of time.
      pixel_buffer_ =
          std::make_unique<uint8_t[]>(SW_RENDERING_PIXEL_BUFFER_SIZE);
      Resize(width_.value_or(1), height_.value_or(1));
      mpv_render_param params[] = {
          {MPV_RENDER_PARAM_API_TYPE, MPV_RENDER_API_TYPE_SW},
          {MPV_RENDER_PARAM_INVALID, nullptr},
      };
      const auto status =
          mpv_render_context_create(&render_context_, handle_, params);
      if (status == 0) {
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
      } else {
        BangumiNativeLog(mpv_error_string(status), true);
      }
    }
  });
  future.wait();
}

VideoOutput::~VideoOutput() {
  BangumiNativeLog("VideoOutput: disposal started");
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
        FlushRenderStatistics(PlaybackRenderClock::now());
        if (surface_manager_) {
          try {
            surface_manager_->MakeCurrent(true);
          } catch (const std::exception& error) {
            // A lost context must not skip mpv cleanup and leave its core
            // waiting forever for a render context that is being disposed.
            BangumiNativeLog(error.what(), true);
          }
        }
        if (render_context_) {
          mpv_render_context_set_update_callback(render_context_, nullptr,
                                                 nullptr);
          mpv_render_context_free(render_context_);
          render_context_ = nullptr;
        }
        if (surface_manager_) {
          try {
            surface_manager_->MakeCurrent(false);
          } catch (const std::exception& error) {
            BangumiNativeLog(error.what(), true);
          }
        }
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
  BangumiNativeLog("VideoOutput: disposal completed");
}

void VideoOutput::NotifyRender() { render_queue_.Request(); }

void VideoOutput::ProcessRender(bool force, double queue_ms,
                                uint64_t requests) {
  if (destroyed_ || !render_context_) return;
  const auto started = PlaybackRenderClock::now();
  PlaybackRenderSample sample;
  sample.sequence = ++render_sequence_;
  sample.size_request = size_request_;
  sample.queue_ms = queue_ms;
  sample.requests = requests;
  sample.force = force;
  try {
    {
      ScopedPlaybackTiming timing(&sample, PlaybackRenderStage::retire);
      RetireSampledTextures();
    }
    uint64_t updates;
    mpv_render_frame_info next_frame{};
    {
      ScopedPlaybackTiming timing(&sample, PlaybackRenderStage::update);
      if (surface_manager_) surface_manager_->MakeCurrent(true, &sample);
      updates = mpv_render_context_update(render_context_);
      // Read the deadline while the update's GL context is already current.
      // This render API query never synchronously waits for the mpv core.
      const auto result = (force || (updates & MPV_RENDER_UPDATE_FRAME))
                              ? mpv_render_context_get_info(
                                    render_context_,
                                    {MPV_RENDER_PARAM_NEXT_FRAME_INFO,
                                     &next_frame})
                              : 0;
      if (surface_manager_) surface_manager_->MakeCurrent(false, &sample);
      if (result < 0) {
        throw std::runtime_error("Unable to get the next video frame deadline.");
      }
    }
    if (!force && !(updates & MPV_RENDER_UPDATE_FRAME)) return;
    {
      ScopedPlaybackTiming timing(&sample, PlaybackRenderStage::resize);
      CheckAndResize(&sample);
    }
    if (SkipLateFrame(&sample, next_frame)) {
      sample.finished = PlaybackRenderClock::now();
      sample.elapsed_ms = PlaybackRenderMilliseconds(sample.finished - started);
      RecordSkip(sample);
      return;
    }
    if (!Render(&sample)) return;
  } catch (const PlaybackGraphicsDeviceLost& error) {
    sample.finished = PlaybackRenderClock::now();
    sample.elapsed_ms = PlaybackRenderMilliseconds(sample.finished - started);
    RecordRender(sample, false, error.what());
    RecoverSoftwareRendering();
    return;
  } catch (const std::exception& error) {
    sample.finished = PlaybackRenderClock::now();
    sample.elapsed_ms = PlaybackRenderMilliseconds(sample.finished - started);
    RecordRender(sample, false, error.what());
    throw;
  } catch (...) {
    sample.finished = PlaybackRenderClock::now();
    sample.elapsed_ms = PlaybackRenderMilliseconds(sample.finished - started);
    RecordRender(sample, false, "Unknown render exception");
    throw;
  }
  sample.finished = PlaybackRenderClock::now();
  sample.elapsed_ms = PlaybackRenderMilliseconds(sample.finished - started);
  RecordRender(sample, true);
}

bool VideoOutput::SkipLateFrame(PlaybackRenderSample* sample,
                               const mpv_render_frame_info& frame) {
  const auto now = mpv_get_time_ns(handle_);
  sample->target_time_ns = frame.target_time;
  sample->frame_flags = frame.flags;
  if (frame.target_time > 0 && now > frame.target_time)
    sample->lateness_ms = (now - frame.target_time) / 1'000'000.0;
  if (!frame_scheduler_.ShouldSkip(frame, now, sample->force,
                                   texture_update_pending_))
    return false;

  // Acknowledge the frame to mpv, allowing its audio clock to advance the VO.
  // This deliberately bypasses Draw/Read, glFinish, snapshot allocation and
  // the GPU copy. A skipped frame must never notify Flutter of a new texture.
  int skip = 1;
  int block = 0;
  mpv_render_param params[]{
      {MPV_RENDER_PARAM_SKIP_RENDERING, &skip},
      {MPV_RENDER_PARAM_BLOCK_FOR_TARGET_TIME, &block},
      {MPV_RENDER_PARAM_INVALID, nullptr},
  };
  ScopedPlaybackTiming timing(sample, PlaybackRenderStage::mpv_render);
  if (surface_manager_) surface_manager_->MakeCurrent(true, sample);
  const auto result = mpv_render_context_render(render_context_, params);
  if (surface_manager_) surface_manager_->MakeCurrent(false, sample);
  if (result < 0) {
    throw std::runtime_error("Unable to skip the overdue video frame.");
  }
  return true;
}

void VideoOutput::RecoverSoftwareRendering() {
  // The lost EGL context cannot service update callbacks or be retried. Free
  // the old render context on its worker so the core can make progress again.
  BangumiNativeLog("VideoOutput: GPU device lost; recovering software output",
                   true);
  mpv_render_context_set_update_callback(render_context_, nullptr, nullptr);
  mpv_render_context_free(render_context_);
  render_context_ = nullptr;
  surface_manager_.reset();

  // Mutations are queued, never synchronously dispatched from the render
  // worker. Reinitialize decoding on the CPU after its D3D device was removed.
  // media_kit owns the client's low request IDs; keep native recovery replies
  // outside that range so they cannot complete a Dart command's waiter.
  constexpr uint64_t recovery_reply = uint64_t{1} << 62;
  const char* hwdec = "no";
  const auto decode_status = mpv_set_property_async(
      handle_, recovery_reply, "hwdec", MPV_FORMAT_STRING, &hwdec);
  if (decode_status < 0) BangumiNativeLog(mpv_error_string(decode_status), true);
  const char* remove_ai[]{"vf", "remove", "@bt-janai", nullptr};
  const auto filter_status =
      mpv_command_async(handle_, recovery_reply + 1, remove_ai);
  if (filter_status < 0) BangumiNativeLog(mpv_error_string(filter_status), true);
  pixel_buffer_ = std::make_unique<uint8_t[]>(SW_RENDERING_PIXEL_BUFFER_SIZE);
  if (width_)
    width_ = std::clamp(*width_, int64_t{0}, int64_t{SW_RENDERING_MAX_WIDTH});
  if (height_)
    height_ =
        std::clamp(*height_, int64_t{0}, int64_t{SW_RENDERING_MAX_HEIGHT});
  Resize((std::max)(int64_t{1}, width_.value_or(1)),
         (std::max)(int64_t{1}, height_.value_or(1)));
  mpv_render_param params[]{
      {MPV_RENDER_PARAM_API_TYPE, MPV_RENDER_API_TYPE_SW},
      {MPV_RENDER_PARAM_INVALID, nullptr},
  };
  const auto status =
      mpv_render_context_create(&render_context_, handle_, params);
  if (status < 0) {
    render_queue_.Close();
    BangumiNativeLog(mpv_error_string(status), true);
    throw std::runtime_error("Unable to recover software video output.");
  }
  mpv_render_context_set_update_callback(
      render_context_,
      [](void* context) { static_cast<VideoOutput*>(context)->NotifyRender(); },
      this);
  render_queue_.Request(true);
}

void VideoOutput::RecordSkip(PlaybackRenderSample& sample) {
  sample.texture = texture_id_;
  sample.width = width();
  sample.height = height();
  ++deadline_skips_;
  render_statistics_.RecordSkip(sample);
  // Skipping still calls the renderer and can block. Record the complete
  // attempt after its scoped stage timing ends, including skip-only intervals.
  if (sample.finished - statistics_since_ >= std::chrono::seconds(10) ||
      ((sample.elapsed_ms >= 50 || sample.queue_ms >= 50) &&
       sample.finished - last_slow_report_ >= std::chrono::seconds(5))) {
    FlushRenderStatistics(sample.finished);
  }
}

void VideoOutput::LogRenderSample(const PlaybackRenderSample& sample,
                                  const char* kind, const char* error) {
  char stages[1024]{};
  size_t used = 0;
  for (size_t i = 0; i < sample.stages.size(); ++i) {
    const auto count = _snprintf_s(
        stages + used, sizeof(stages) - used, _TRUNCATE, "%s=%.2f ",
        PlaybackRenderStageName(static_cast<PlaybackRenderStage>(i)),
        sample.stages[i]);
    if (count < 0) break;
    used += static_cast<size_t>(count);
  }
  char message[2048]{};
  _snprintf_s(
      message, sizeof(message), _TRUNCATE,
      "VideoOutput %s handle=%p sequence=%llu size_request=%llu "
      "texture=%lld size=%lldx%lld force=%d requests=%llu gpu_polls=%llu "
      "queue_ms=%.2f render_ms=%.2f age_ms=%.2f "
      "target_time_ns=%lld frame_flags=%llu "
      "lateness_ms=%.2f output_lateness_ms=%.2f "
      "failed_stage=%s stages_ms={%s} error=%s",
      kind, handle_, sample.sequence, sample.size_request,
      static_cast<long long>(sample.texture),
      static_cast<long long>(sample.width),
      static_cast<long long>(sample.height), sample.force ? 1 : 0,
      sample.requests, sample.gpu_polls, sample.queue_ms, sample.elapsed_ms,
      PlaybackRenderMilliseconds(PlaybackRenderClock::now() - sample.finished),
      static_cast<long long>(sample.target_time_ns), sample.frame_flags,
      sample.lateness_ms, sample.output_lateness_ms,
      sample.failed_stage ? sample.failed_stage : "none", stages,
      error ? error : "none");
  BangumiNativeLog(message, error != nullptr);
}

void VideoOutput::RecordRender(PlaybackRenderSample& sample, bool success,
                               const char* error) {
  sample.texture = texture_id_;
  sample.width = width();
  sample.height = height();
  if (success && sample.target_time_ns > 0) {
    const auto now = mpv_get_time_ns(handle_);
    if (now > sample.target_time_ns)
      sample.output_lateness_ms = (now - sample.target_time_ns) / 1'000'000.0;
  }
  render_statistics_.Record(sample, success);
  if (!success) {
    ++render_errors_;
    if (render_errors_ == 1 ||
        sample.finished - last_render_error_ >= std::chrono::seconds(5)) {
      LogRenderSample(sample, "failure", error);
      last_render_error_ = sample.finished;
    }
  }
  // Failed attempts contribute to every timing/count, not just errors_total.
  // Fixed thresholds let Dart's FPS/rate budget explain sub-50ms slowdowns
  // without synchronous mpv property reads on the render worker.
  if (sample.finished - statistics_since_ >= std::chrono::seconds(10) ||
      ((sample.elapsed_ms >= 50 || sample.queue_ms >= 50 || !success) &&
       sample.finished - last_slow_report_ >= std::chrono::seconds(5))) {
    FlushRenderStatistics(sample.finished);
  }
}

void VideoOutput::FlushRenderStatistics(
    PlaybackRenderClock::time_point finished) {
  const auto& stats = render_statistics_;
  if (stats.attempts == 0 && stats.deadline_skips == 0) return;
  const auto divisor = stats.attempts ? stats.attempts : uint64_t{1};
  char stages[1536]{};
  size_t used = 0;
  for (size_t i = 0; i < stats.totals.size(); ++i) {
    const auto count = _snprintf_s(
        stages + used, sizeof(stages) - used, _TRUNCATE, "%s=%.2f/%.2f ",
        PlaybackRenderStageName(static_cast<PlaybackRenderStage>(i)),
        stats.totals[i] / divisor, stats.maxima[i]);
    if (count < 0) break;
    used += static_cast<size_t>(count);
  }
  char message[2048]{};
  _snprintf_s(message, sizeof(message), _TRUNCATE,
              "VideoOutput handle=%p texture=%lld size=%lldx%lld "
              "attempts=%llu frames=%llu failures=%llu interval_ms=%.1f "
              "render_avg_ms=%.2f render_max_ms=%.2f "
              "over_20ms=%llu over_33ms=%llu slow_frames=%llu "
              "errors_total=%llu queue_avg_ms=%.2f queue_max_ms=%.2f "
              "deadline_skips=%llu deadline_skips_total=%llu "
              "skip_avg_ms=%.2f skip_max_ms=%.2f skip_queue_max_ms=%.2f "
              "skip_lateness_max_ms=%.2f lateness_max_ms=%.2f "
              "output_lateness_max_ms=%.2f "
              "stages_avg_max_ms={%s}",
              handle_, static_cast<long long>(texture_id_),
              static_cast<long long>(width()), static_cast<long long>(height()),
              stats.attempts, stats.frames, stats.failures,
              PlaybackRenderMilliseconds(finished - statistics_since_),
              stats.total_ms / divisor, stats.worst.elapsed_ms,
              stats.over_20, stats.over_33, stats.over_50, render_errors_,
              stats.queue_total_ms / divisor, stats.queue_max_ms,
              stats.deadline_skips, deadline_skips_,
              stats.deadline_skips
                  ? stats.skip_total_ms / stats.deadline_skips
                  : 0,
              stats.worst_skip.elapsed_ms, stats.skip_queue_max_ms,
              stats.skip_lateness_max_ms, stats.lateness_max_ms,
              stats.output_lateness_max_ms, stages);
  BangumiNativeLog(message);
  if (stats.attempts) LogRenderSample(stats.worst, "worst");
  if (stats.queue_max_ms >= 50 &&
      stats.longest_queue.sequence != stats.worst.sequence)
    LogRenderSample(stats.longest_queue, "queue_worst");
  if (stats.worst_skip.elapsed_ms >= 50)
    LogRenderSample(stats.worst_skip, "skip_worst");
  if (stats.skip_queue_max_ms >= 50 &&
      (stats.worst_skip.elapsed_ms < 50 ||
       stats.longest_skip_queue.sequence != stats.worst_skip.sequence))
    LogRenderSample(stats.longest_skip_queue, "skip_queue_worst");
  if (stats.over_50 > 0 || stats.failures > 0 || stats.queue_max_ms >= 50 ||
      stats.worst_skip.elapsed_ms >= 50 || stats.skip_queue_max_ms >= 50)
    last_slow_report_ = finished;
  statistics_since_ = finished;
  render_statistics_ = {};
}

bool VideoOutput::Render(PlaybackRenderSample* sample) {
  if (destroyed_ || !texture_id_) return false;
  // video-timing-offset is zero. Do not wait for the core's presentation signal
  // while holding the surface mutex needed by Flutter's texture callback.
  int block_for_target_time = 0;
  if (surface_manager_) {
    surface_manager_->Draw(
        [&]() {
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
        },
        sample);
    // Copy and wait on this worker, never in Flutter's raster callback.
    surface_manager_->Read(sample);
    ScopedPlaybackTiming frame_timing(sample, PlaybackRenderStage::frame_store);
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
    ScopedPlaybackTiming timing(sample, PlaybackRenderStage::mpv_render);
    if (mpv_render_context_render(render_context_, params) < 0) {
      throw std::runtime_error("Unable to render the software video frame.");
    }
  }
  ScopedPlaybackTiming timing(sample, PlaybackRenderStage::publish);
  PublishTexture();
  registrar_->texture_registrar()->MarkTextureFrameAvailable(texture_id_);
  return true;
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
  const auto requested = PlaybackRenderClock::now();
  thread_pool_ref_->Post([this, width, height, requested]() {
    if (destroyed_) return;
    if (width_ != width || height_ != height) {
      char message[512]{};
      _snprintf_s(
          message, sizeof(message), _TRUNCATE,
          "VideoOutput size request handle=%p size_request=%llu "
          "old_requested=%lldx%lld new_requested=%lldx%lld "
          "output=%lldx%lld queue_ms=%.2f",
          handle_, ++size_request_, width_.value_or(0), height_.value_or(0),
          width.value_or(0), height.value_or(0), this->width(), this->height(),
          PlaybackRenderMilliseconds(PlaybackRenderClock::now() - requested));
      BangumiNativeLog(message);
    }
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

void VideoOutput::CheckAndResize(PlaybackRenderSample* sample) {
  const auto required_width = GetVideoWidth();
  const auto required_height = GetVideoHeight();
  if (required_width < 1 || required_height < 1) return;
  if (required_width == width() && required_height == height()) return;
  Resize(required_width, required_height, sample);
}

void VideoOutput::Resize(int64_t required_width, int64_t required_height,
                         PlaybackRenderSample* sample) {
  const auto started = PlaybackRenderClock::now();
  char message[512]{};
  _snprintf_s(message, sizeof(message), _TRUNCATE,
              "VideoOutput resize begin handle=%p size_request=%llu "
              "sequence=%llu old_texture=%lld old_size=%lldx%lld "
              "new_size=%lldx%lld",
              handle_, size_request_, sample ? sample->sequence : uint64_t{0},
              texture_id_, width(), height(), required_width, required_height);
  BangumiNativeLog(message);
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
                              static_cast<int32_t>(required_height), sample);
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
  _snprintf_s(message, sizeof(message), _TRUNCATE,
              "VideoOutput resize completed handle=%p size_request=%llu "
              "sequence=%llu texture=%lld size=%lldx%lld elapsed_ms=%.2f "
              "first_frame_pending=1",
              handle_, size_request_, sample ? sample->sequence : uint64_t{0},
              texture_id_, width(), height(),
              PlaybackRenderMilliseconds(PlaybackRenderClock::now() - started));
  BangumiNativeLog(message);
}

void VideoOutput::PublishTexture() {
  if (!texture_update_pending_) return;
  texture_update_pending_ = false;
  const bool has_video_size = GetVideoWidth() > 0 && GetVideoHeight() > 0;
  texture_update_callback_(texture_id_, has_video_size ? width() : 0,
                           has_video_size ? height() : 0);
  if (has_video_size) {
    char message[384]{};
    _snprintf_s(message, sizeof(message), _TRUNCATE,
                "VideoOutput first frame ready handle=%p size_request=%llu "
                "sequence=%llu texture=%lld size=%lldx%lld",
                handle_, size_request_, render_sequence_, texture_id_, width(),
                height());
    BangumiNativeLog(message);
  }
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
