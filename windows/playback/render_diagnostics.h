#ifndef BANGUMI_PLAYBACK_RENDER_DIAGNOSTICS_H_
#define BANGUMI_PLAYBACK_RENDER_DIAGNOSTICS_H_

#include <algorithm>
#include <array>
#include <chrono>
#include <cstdint>
#include <exception>

enum class PlaybackRenderStage {
  retire,
  update,
  resize,
  surface_lock,
  context,
  surface_create,
  mpv_render,
  swap,
  snapshot,
  share,
  copy_submit,
  prior_copy,
  copy_wait,
  frame_store,
  publish,
  count
};

inline const char* PlaybackRenderStageName(PlaybackRenderStage stage) {
  static constexpr const char* names[]{
      "retire",         "update",     "resize",    "surface_lock", "context",
      "surface_create", "mpv_render", "swap",      "snapshot",     "share",
      "copy_submit",    "prior_copy", "copy_wait", "frame_store", "publish"};
  return names[static_cast<size_t>(stage)];
}

using PlaybackRenderClock = std::chrono::steady_clock;
inline double PlaybackRenderMilliseconds(PlaybackRenderClock::duration value) {
  return std::chrono::duration<double, std::milli>(value).count();
}

struct PlaybackRenderSample {
  static constexpr size_t stage_count =
      static_cast<size_t>(PlaybackRenderStage::count);
  std::array<double, stage_count> stages{};
  PlaybackRenderClock::time_point finished{};
  uint64_t sequence = 0;
  uint64_t size_request = 0;
  uint64_t requests = 0;
  uint64_t gpu_polls = 0;
  int64_t texture = 0;
  int64_t width = 0;
  int64_t height = 0;
  double elapsed_ms = 0;
  double queue_ms = 0;
  const char* failed_stage = nullptr;
  bool force = false;
};

// Records partial work during exception unwinding as well as successful calls.
// Nested stages (resize/surface_create, update/context) overlap intentionally.
class ScopedPlaybackTiming {
 public:
  ScopedPlaybackTiming(PlaybackRenderSample* sample, PlaybackRenderStage stage)
      : sample_(sample),
        stage_(stage),
        started_(PlaybackRenderClock::now()),
        exceptions_(std::uncaught_exceptions()) {}
  ~ScopedPlaybackTiming() { Finish(); }
  ScopedPlaybackTiming(const ScopedPlaybackTiming&) = delete;
  ScopedPlaybackTiming& operator=(const ScopedPlaybackTiming&) = delete;
  void Finish() noexcept {
    if (!sample_) return;
    sample_->stages[static_cast<size_t>(stage_)] +=
        PlaybackRenderMilliseconds(PlaybackRenderClock::now() - started_);
    if (std::uncaught_exceptions() > exceptions_ && !sample_->failed_stage) {
      sample_->failed_stage = PlaybackRenderStageName(stage_);
    }
    sample_ = nullptr;
  }

 private:
  PlaybackRenderSample* sample_;
  PlaybackRenderStage stage_;
  PlaybackRenderClock::time_point started_;
  int exceptions_;
};

struct PlaybackRenderStatistics {
  uint64_t attempts = 0;
  uint64_t frames = 0;
  uint64_t failures = 0;
  uint64_t over_20 = 0;
  uint64_t over_33 = 0;
  uint64_t over_50 = 0;
  double total_ms = 0;
  double queue_total_ms = 0;
  double queue_max_ms = 0;
  std::array<double, PlaybackRenderSample::stage_count> totals{};
  std::array<double, PlaybackRenderSample::stage_count> maxima{};
  PlaybackRenderSample worst{};
  PlaybackRenderSample longest_queue{};

  void Record(const PlaybackRenderSample& sample, bool success) {
    ++attempts;
    if (success)
      ++frames;
    else
      ++failures;
    if (sample.elapsed_ms >= 20) ++over_20;
    if (sample.elapsed_ms >= 33) ++over_33;
    if (sample.elapsed_ms >= 50) ++over_50;
    total_ms += sample.elapsed_ms;
    queue_total_ms += sample.queue_ms;
    queue_max_ms = (std::max)(queue_max_ms, sample.queue_ms);
    for (size_t i = 0; i < totals.size(); ++i) {
      totals[i] += sample.stages[i];
      maxima[i] = (std::max)(maxima[i], sample.stages[i]);
    }
    if (attempts == 1 || sample.elapsed_ms > worst.elapsed_ms) worst = sample;
    if (attempts == 1 || sample.queue_ms > longest_queue.queue_ms)
      longest_queue = sample;
  }
};

#endif  // BANGUMI_PLAYBACK_RENDER_DIAGNOSTICS_H_
