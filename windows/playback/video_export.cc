#include "video_export.h"

#include <algorithm>
#include <array>
#include <atomic>
#include <chrono>
#include <cmath>
#include <condition_variable>
#include <cstring>
#include <deque>
#include <memory>
#include <mutex>
#include <stdexcept>
#include <string>
#include <thread>
#include <vector>

#include <client.h>
#include <render.h>
#include <render_gl.h>
#include <stream_cb.h>

#include "angle_surface_manager.h"

namespace {
using Bytes = std::vector<uint8_t>;
using Frame = std::shared_ptr<Bytes>;
using Clock = std::chrono::steady_clock;

// Both mpv queues wake the same worker. Callbacks only signal; all core and GL
// work stays on the rendering thread, including advanced-control updates.
class RenderWakeup {
 public:
  static void Notify(void* context) {
    auto& wakeup = *static_cast<RenderWakeup*>(context);
    std::lock_guard<std::mutex> lock(wakeup.mutex_);
    wakeup.pending_ = true;
    wakeup.changed_.notify_one();
  }
  void Wait(const std::atomic<bool>& cancelled) {
    std::unique_lock<std::mutex> lock(mutex_);
    changed_.wait_for(lock, std::chrono::milliseconds(100),
                      [&] { return pending_ || cancelled; });
    pending_ = false;
  }

 private:
  std::mutex mutex_;
  std::condition_variable changed_;
  bool pending_ = false;
};

void Check(int code, const char* operation) {
  if (code < 0)
    throw std::runtime_error(std::string(operation) + ": " +
                             mpv_error_string(code));
}

struct Core {
  mpv_handle* handle = mpv_create();
  Core() {
    if (!handle) throw std::runtime_error("Cannot create export player");
  }
  ~Core() { mpv_terminate_destroy(handle); }
  void Set(const char* name, const std::string& value) {
    Check(mpv_set_option_string(handle, name, value.c_str()), name);
  }
  void Common() {
    Set("config", "no");
    Set("scripts", "");
    Set("load-scripts", "no");
    Set("idle", "yes");
    Set("terminal", "no");
    Set("input-default-bindings", "no");
    Set("osc", "no");
    Set("sub-auto", "no");
    Set("sid", "no");
    Set("audio-file-auto", "no");
  }
  void FileList(const char* name, const std::string& file) {
    mpv_node value{};
    value.format = MPV_FORMAT_STRING;
    value.u.string = const_cast<char*>(file.c_str());
    mpv_node_list list{1, &value, nullptr};
    mpv_node node{};
    node.format = MPV_FORMAT_NODE_ARRAY;
    node.u.list = &list;
    Check(mpv_set_option(handle, name, MPV_FORMAT_NODE, &node), name);
  }
  void Load(const std::string& file) {
    const char* args[] = {"loadfile", file.c_str(), nullptr};
    Check(mpv_command_async(handle, 0, args), "loadfile");
  }
};

// A bounded stream connects GPU readback to mpv's existing H.264/AAC encoder.
// Neither a second FFmpeg distribution nor an on-disk frame sequence is needed.
class FrameStream {
 public:
  explicit FrameStream(size_t frame_bytes) : frame_bytes_(frame_bytes) {}
  Frame Acquire(const std::atomic<bool>& cancelled) {
    std::unique_lock<std::mutex> lock(mutex_);
    for (;;) {
      if (cancelled || stopped_) throw std::runtime_error("Export interrupted");
      // A queued frame is immutable, including VFR duplicates. Reuse its
      // storage only after both the renderer and stream reader release it.
      for (auto& frame : buffers_) {
        // Allocate on the export worker, never on the FFI caller's UI thread.
        if (!frame) frame = std::make_shared<Bytes>(frame_bytes_);
        if (frame.use_count() == 1) return frame;
      }
      changed_.wait(lock);
    }
  }
  void Push(const Frame& frame, const std::atomic<bool>& cancelled) {
    std::unique_lock<std::mutex> lock(mutex_);
    changed_.wait(lock,
                  [&] { return frames_.size() < 2 || stopped_ || cancelled; });
    if (cancelled || stopped_) throw std::runtime_error("Export interrupted");
    frames_.push_back(frame);
    changed_.notify_all();
  }
  void Finish() {
    std::lock_guard<std::mutex> lock(mutex_);
    eof_ = true;
    changed_.notify_all();
  }
  void Stop() {
    std::lock_guard<std::mutex> lock(mutex_);
    stopped_ = true;
    changed_.notify_all();
  }
  static int Open(void* cookie, char*, mpv_stream_cb_info* info) {
    info->cookie = cookie;
    info->read_fn = [](void* p, char* data, uint64_t size) -> int64_t {
      return static_cast<FrameStream*>(p)->Read(data, size);
    };
    info->close_fn = [](void*) {};
    info->cancel_fn = [](void* p) { static_cast<FrameStream*>(p)->Stop(); };
    return 0;
  }

 private:
  int64_t Read(char* data, uint64_t size) {
    std::unique_lock<std::mutex> lock(mutex_);
    changed_.wait(lock, [&] { return stopped_ || eof_ || !frames_.empty(); });
    if (stopped_) return -1;
    if (frames_.empty()) return 0;
    auto& frame = frames_.front();
    const size_t count =
        static_cast<size_t>(std::min<uint64_t>(size, frame->size() - offset_));
    std::memcpy(data, frame->data() + offset_, count);
    offset_ += count;
    if (offset_ == frame->size()) {
      frames_.pop_front();
      offset_ = 0;
      changed_.notify_all();
    }
    return static_cast<int64_t>(count);
  }
  std::mutex mutex_;
  std::condition_variable changed_;
  // Two queued frames plus the renderer's current and previous frame. The
  // fixed pool bounds memory even when the encoder is slower than rendering.
  std::array<Frame, 4> buffers_;
  const size_t frame_bytes_;
  std::deque<Frame> frames_;
  size_t offset_ = 0;
  bool eof_ = false;
  bool stopped_ = false;
};

struct Export {
  std::string source, target, shaders, filter, format;
  int width, height;
  double fps;
  std::atomic<bool> cancelled{false};
  std::atomic<int> state{0};
  std::atomic<double> progress{0};
  RenderWakeup wakeup;
  FrameStream stream;
  std::string error;
  std::thread worker;

  explicit Export(const PlaybackExportRequest& r)
      : source(r.source), target(r.target), shaders(r.shaders), filter(r.filter),
        format(r.format), width(r.width), height(r.height), fps(r.fps),
        stream(static_cast<size_t>(r.width) * r.height * 4) {}

  void Encode() {
    Core encoder;
    encoder.Common();
    encoder.Set("o", target);
    encoder.Set("of", format);
    const bool webm = format == "webm";
    encoder.Set("ovc", webm ? "libvpx-vp9" : "libx264");
    encoder.Set("ovcopts", webm ? "crf=24,b=0" : "crf=18,preset=medium");
    encoder.Set("oac", webm ? "libopus" : format == "avi" ? "libmp3lame" : "aac");
    encoder.Set("oacopts", "b=192000");
    encoder.Set("vf", "format=fmt=yuv420p:colormatrix=bt.709:colorlevels=limited");
    encoder.Set("demuxer", "rawvideo");
    encoder.Set("demuxer-rawvideo-w", std::to_string(width));
    encoder.Set("demuxer-rawvideo-h", std::to_string(height));
    encoder.Set("demuxer-rawvideo-fps", std::to_string(fps));
    encoder.Set("demuxer-rawvideo-mp-format", "rgba");
    encoder.FileList("audio-files", source);
    encoder.Set("audio-demuxer", "lavf");
    encoder.Set("demuxer-readahead-secs", "0");
    encoder.Set("demuxer-max-bytes", "64MiB");
    Check(mpv_initialize(encoder.handle), "Initialize encoder");
    Check(mpv_request_log_messages(encoder.handle, "error"), "Read encoder errors");
    Check(mpv_stream_cb_add_ro(encoder.handle, "btexport", &stream,
                               FrameStream::Open), "Register frame stream");
    encoder.Load("btexport://frames");
    std::string last_error;
    for (;;) {
      auto* event = mpv_wait_event(encoder.handle, 0.1);
      if (event->event_id == MPV_EVENT_LOG_MESSAGE) {
        auto* log = static_cast<mpv_event_log_message*>(event->data);
        if (last_error.size() < 8192)
          last_error += std::string(log->prefix) + ": " + log->text;
      }
      if (event->event_id == MPV_EVENT_END_FILE) {
        const auto end = *static_cast<mpv_event_end_file*>(event->data);
        // Stop() unblocks raw input. Let the encoder finish unloading before
        // destroying its core, even if cancelled during encoder startup.
        if (cancelled) return;
        if (end.reason != MPV_END_FILE_REASON_EOF)
          throw std::runtime_error(std::string("Encoding failed: ") +
                                   mpv_error_string(end.error) + " " + last_error);
        if (!last_error.empty()) throw std::runtime_error(last_error);
        return;
      }
      if (event->event_id == MPV_EVENT_SHUTDOWN)
        throw std::runtime_error("Encoder stopped unexpectedly");
    }
  }

  void Render() {
    Core decoder;
    decoder.Common();
    decoder.Set("vo", "libmpv");
    decoder.Set("hwdec", "d3d11va");
    decoder.Set("hwdec-codecs", "all");
    decoder.Set("aid", "no");
    decoder.Set("pause", "yes");
    decoder.Set("keep-open", "yes");
    decoder.Set("framedrop", "no");
    decoder.Set("video-sync", "desync");
    // Frame-step briefly unpauses the core. Accelerate that private clock as
    // well as disabling presentation waits; output still uses source PTS/fps.
    decoder.Set("untimed", "yes");
    decoder.Set("speed", "100");
    decoder.Set("osd-level", "0");
    decoder.Set("gpu-dumb-mode", "no");
    decoder.Set("glsl-shaders", shaders);
    if (!filter.empty()) decoder.Set("vf", filter);
    Check(mpv_initialize(decoder.handle), "Initialize renderer");
    Check(mpv_request_log_messages(decoder.handle, "error"), "Read render errors");
    Check(mpv_observe_property(decoder.handle, 2, "eof-reached", MPV_FORMAT_FLAG),
          "Observe export EOF");
    mpv_set_wakeup_callback(decoder.handle, RenderWakeup::Notify, &wakeup);

    ANGLESurfaceManager surface(width, height);
    surface.MakeCurrent(true);
    mpv_opengl_init_params gl{
        [](void*, const char* name) -> void* {
          return reinterpret_cast<void*>(eglGetProcAddress(name));
        }, nullptr};
    int advanced = 1;
    mpv_render_param params[] = {
        {MPV_RENDER_PARAM_API_TYPE, const_cast<char*>(MPV_RENDER_API_TYPE_OPENGL)},
        {MPV_RENDER_PARAM_OPENGL_INIT_PARAMS, &gl},
        {MPV_RENDER_PARAM_ADVANCED_CONTROL, &advanced},
        {MPV_RENDER_PARAM_INVALID, nullptr}};
    mpv_render_context* raw = nullptr;
    Check(mpv_render_context_create(&raw, decoder.handle, params),
          "Create GPU renderer");
    auto destroy = [&surface](mpv_render_context* p) {
      surface.MakeCurrent(true);
      mpv_render_context_free(p);
      surface.MakeCurrent(false);
    };
    std::unique_ptr<mpv_render_context, decltype(destroy)> render(raw, destroy);
    mpv_render_context_set_update_callback(raw, RenderWakeup::Notify, &wakeup);
    decoder.Load(source);

    Frame current = stream.Acquire(cancelled), previous;
    bool have_frame = false, requested_pts = false, eof = false;
    uint64_t output_frames = 0;
    double previous_pts = 0;
    auto activity = Clock::now();
    auto write_until = [&](double end) {
      while (static_cast<double>(output_frames) / fps + 1e-7 < end) {
        stream.Push(previous, cancelled);
        ++output_frames;
        progress = static_cast<double>(output_frames) / fps;
      }
    };
    while (!cancelled) {
      // Advanced render control must be pumped even while awaiting async core
      // replies. Never query the core synchronously on the rendering thread.
      const uint64_t updates = mpv_render_context_update(raw);
      if (updates & MPV_RENDER_UPDATE_FRAME) {
        mpv_render_frame_info info{};
        mpv_render_param next{MPV_RENDER_PARAM_NEXT_FRAME_INFO, &info};
        Check(mpv_render_context_get_info(raw, next), "Read frame info");
        if (info.flags & MPV_RENDER_FRAME_INFO_PRESENT) {
          const bool fresh = !(info.flags & MPV_RENDER_FRAME_INFO_REDRAW);
          // This private surface belongs to this worker for the entire export.
          // Keep its context current; no Flutter snapshot or cross-thread
          // surface publication is needed. ReadPixels synchronizes the draw.
          {
            mpv_opengl_fbo fbo{0, width, height, 0};
            // glReadPixels reads from the bottom row. mpv's default GL
            // orientation already compensates for this in raw readback.
            int block = 0;
            mpv_render_param draw[] = {
                {MPV_RENDER_PARAM_OPENGL_FBO, &fbo},
                {MPV_RENDER_PARAM_BLOCK_FOR_TARGET_TIME, &block},
                {MPV_RENDER_PARAM_INVALID, nullptr}};
            Check(mpv_render_context_render(raw, draw), "Render frame");
            if (fresh) {
              // Let the core answer while GPU readback completes. Pausing
              // keeps this PTS stable until we explicitly step the next frame.
              if (!requested_pts) {
                Check(mpv_get_property_async(decoder.handle, 1, "time-pos",
                                             MPV_FORMAT_DOUBLE),
                      "Read frame timestamp");
                requested_pts = true;
              }
              glReadPixels(0, 0, width, height, GL_RGBA, GL_UNSIGNED_BYTE,
                           current->data());
              if (glGetError() != GL_NO_ERROR)
                throw std::runtime_error("GPU frame readback failed");
            }
          }
          if (fresh) have_frame = true;
          activity = Clock::now();
        }
      }
      // Paused frame stepping keeps time-pos stable until that frame has been
      // copied. Resampling by PTS preserves VFR timing and the original audio.
      auto* event = mpv_wait_event(decoder.handle, 0);
      if (event->event_id == MPV_EVENT_GET_PROPERTY_REPLY &&
          event->reply_userdata == 1) {
        Check(event->error, "Read frame timestamp");
        auto* value = static_cast<mpv_event_property*>(event->data);
        if (!value->data) throw std::runtime_error("Missing frame timestamp");
        const double pts = *static_cast<double*>(value->data);
        if (!std::isfinite(pts)) throw std::runtime_error("Invalid frame timestamp");
        if (previous) write_until((std::max)(previous_pts, pts));
        previous = std::move(current);
        current = stream.Acquire(cancelled);
        previous_pts = (std::max)(0.0, pts);
        have_frame = requested_pts = false;
        const char* step[] = {"frame-step", nullptr};
        Check(mpv_command_async(decoder.handle, 0, step), "Step export frame");
        activity = Clock::now();
      } else if (event->event_id == MPV_EVENT_END_FILE) {
        auto* end = static_cast<mpv_event_end_file*>(event->data);
        if (end->reason != MPV_END_FILE_REASON_EOF)
          throw std::runtime_error(std::string("Decoding failed: ") +
                                   mpv_error_string(end->error));
        eof = true;
      } else if (event->event_id == MPV_EVENT_PROPERTY_CHANGE &&
                 event->reply_userdata == 2) {
        auto* property = static_cast<mpv_event_property*>(event->data);
        if (property->data) eof = *static_cast<int*>(property->data) != 0;
      } else if (event->event_id == MPV_EVENT_COMMAND_REPLY && event->error < 0) {
        Check(event->error, "Decode command");
      } else if (event->event_id == MPV_EVENT_LOG_MESSAGE) {
        auto* log = static_cast<mpv_event_log_message*>(event->data);
        const std::string prefix = log->prefix;
        // mpv probes several hardware interop APIs before selecting one. An
        // unsuccessful alternative is expected, even when rendering succeeds.
        if (prefix.find("/dxva2-") == std::string::npos &&
            prefix.find("/d3d11-") == std::string::npos && prefix != "vd")
          throw std::runtime_error(prefix + ": " + log->text);
      }
      if (eof && !have_frame && !requested_pts) {
        if (!previous) throw std::runtime_error("No video frames decoded");
        // Do not stretch to container duration: the audio can outlast video.
        write_until(previous_pts + 1.0 / fps);
        // mpv's lavc VO does not forward AVFrame.duration. ISO BMFF muxers
        // consequently write a zero-duration last sample and an edit list
        // ending at that sample's PTS. A terminal duplicate establishes the
        // end boundary of the last real frame; the edit list excludes the
        // zero-duration boundary sample itself. Other muxers need no marker.
        if (format == "mp4" || format == "mov") stream.Push(previous, cancelled);
        stream.Finish();
        return;
      }
      const auto timeout = !previous && !filter.empty()
                               ? std::chrono::seconds(1800)
                               : std::chrono::seconds(30);
      if (Clock::now() - activity > timeout)
        throw std::runtime_error("Video export timed out waiting for a frame");
      if (event->event_id == MPV_EVENT_NONE) wakeup.Wait(cancelled);
    }
  }

  void Run() noexcept {
    std::thread encoder;
    std::exception_ptr encoding_error;
    try {
      encoder = std::thread([&] {
        try { Encode(); }
        catch (...) { encoding_error = std::current_exception(); stream.Stop(); }
      });
      Render();
      if (cancelled) stream.Stop();
      encoder.join();
      if (encoding_error) std::rethrow_exception(encoding_error);
      state = cancelled ? 2 : 1;
    } catch (const std::exception& e) {
      stream.Stop();
      if (encoder.joinable()) encoder.join();
      error = e.what();
      if (encoding_error && error == "Export interrupted") {
        try { std::rethrow_exception(encoding_error); }
        catch (const std::exception& e2) { error = e2.what(); }
      }
      state = cancelled ? 2 : 3;
    } catch (...) {
      stream.Stop();
      if (encoder.joinable()) encoder.join();
      error = "Unexpected video export failure";
      state = cancelled ? 2 : 3;
    }
  }
};
}  // namespace

void* bt_video_export_start(const PlaybackExportRequest* request) try {
  if (!request || !request->source || !request->target || !request->shaders ||
      !request->filter || !request->format || request->width < 2 || request->height < 2 ||
      request->width > 4096 || request->height > 4096 ||
      static_cast<int64_t>(request->width) * request->height > 3840 * 2160 ||
      !std::isfinite(request->fps) || request->fps <= 0 || request->fps > 240)
    return nullptr;
  auto job = std::make_unique<Export>(*request);
  auto* pointer = job.get();
  job->worker = std::thread([pointer] { pointer->Run(); });
  return job.release();
} catch (...) { return nullptr; }

int bt_video_export_state(void* job) { return static_cast<Export*>(job)->state; }
double bt_video_export_progress(void* job) {
  return static_cast<Export*>(job)->progress;
}
const char* bt_video_export_error(void* job) {
  auto* export_job = static_cast<Export*>(job);
  return export_job->state == 0 ? "" : export_job->error.c_str();
}
void bt_video_export_cancel(void* job) {
  auto* export_job = static_cast<Export*>(job);
  export_job->cancelled = true;
  export_job->stream.Stop();
  RenderWakeup::Notify(&export_job->wakeup);
}
void bt_video_export_close(void* job) {
  auto* export_job = static_cast<Export*>(job);
  bt_video_export_cancel(job);
  if (export_job->worker.joinable()) export_job->worker.join();
  delete export_job;
}
