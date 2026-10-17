#ifndef BANGUMI_PLAYBACK_FRAME_SCHEDULER_H_
#define BANGUMI_PLAYBACK_FRAME_SCHEDULER_H_

#include <cmath>
#include <cstdint>

// Render-side copy of the next mpv frame deadline. Keeping the policy free of
// libmpv headers lets the scheduler be regression-tested without a player
// build; video_output.cc asserts these flags against the pinned runtime.
struct PlaybackFrameInfo {
  static constexpr uint64_t kPresent = 1ULL << 0;
  static constexpr uint64_t kRedraw = 1ULL << 1;
  static constexpr uint64_t kRepeat = 1ULL << 2;
  static constexpr uint64_t kBlockVsync = 1ULL << 3;

  uint64_t flags = 0;
  int64_t target_time = 0;
};

// Consume overdue video frames without submitting more work to a busy GPU.
// The pinned libmpv runtime reports target_time in nanoseconds (despite the
// stale microsecond comment in render.h); compare it with mpv_get_time_ns.
class PlaybackFrameScheduler {
 public:
  bool ShouldSkip(const PlaybackFrameInfo& frame, int64_t now_ns, bool force,
                  bool first_frame) {
    if (first_frame) Reset();
    if (!IsTimed(frame)) {
      consecutive_skips_ = 0;
      return false;
    }
    ObserveTarget(frame.target_time);
    // A slightly late frame can still be useful before the following frame.
    // Reserve the recent render cost, but allow at least half a frame of
    // scheduling jitter so slow rendering cannot starve every late frame.
    const double half_interval = frame_interval_ns_ / 2.0;
    const double render_cost =
        render_ns_ < half_interval ? render_ns_ : half_interval;
    const double tolerance = frame_interval_ns_ - render_cost;
    const bool overdue = frame_interval_ns_ > 0 && now_ns > frame.target_time &&
                         now_ns - frame.target_time >= tolerance;
    if (!force && !first_frame && overdue &&
        consecutive_skips_ < kMaxConsecutiveSkips) {
      ++consecutive_skips_;
      return true;
    }
    // Always make progress even when every frame misses its deadline. Redraws,
    // first frames and forced output changes must still publish a real image.
    consecutive_skips_ = 0;
    return false;
  }

  // Only completed, timed renders teach the estimate. Skips and redraws must
  // not make rendering appear cheaper; callers also exclude forced resizes.
  void RecordRender(const PlaybackFrameInfo& frame, double elapsed_ms) {
    if (!IsTimed(frame) || frame.target_time != last_target_ns_ ||
        frame_interval_ns_ == 0 || !std::isfinite(elapsed_ms) ||
        elapsed_ms <= 0)
      return;
    const double elapsed_ns = elapsed_ms >= frame_interval_ns_ / 1'000'000.0
                                  ? static_cast<double>(frame_interval_ns_)
                                  : elapsed_ms * 1'000'000.0;
    render_ns_ = render_ns_ == 0 ? elapsed_ns
                                 : render_ns_ + (elapsed_ns - render_ns_) / 8;
  }

 private:
  static bool IsTimed(const PlaybackFrameInfo& frame) {
    constexpr uint64_t untimed = PlaybackFrameInfo::kRedraw |
                                 PlaybackFrameInfo::kRepeat |
                                 PlaybackFrameInfo::kBlockVsync;
    return (frame.flags & PlaybackFrameInfo::kPresent) &&
           !(frame.flags & untimed) && frame.target_time > 0;
  }

  void Reset() {
    last_target_ns_ = frame_interval_ns_ = 0;
    render_ns_ = 0;
    consecutive_skips_ = 0;
  }

  void ObserveTarget(int64_t target_ns) {
    if (last_target_ns_ > 0 && target_ns > last_target_ns_) {
      const auto interval = target_ns - last_target_ns_;
      // Reject discontinuities and re-learn after pause/seek. Ordinary cadence
      // changes (including playback speed) immediately replace the old budget.
      if (interval < 1'000'000 || interval > 1'000'000'000) {
        frame_interval_ns_ = 0;
        render_ns_ = 0;
        consecutive_skips_ = 0;
      } else {
        if (frame_interval_ns_ > 0 &&
            (interval < frame_interval_ns_ - frame_interval_ns_ / 4 ||
             interval > frame_interval_ns_ + frame_interval_ns_ / 4)) {
          render_ns_ = 0;
          consecutive_skips_ = 0;
        }
        frame_interval_ns_ = interval;
      }
    } else if (target_ns < last_target_ns_) {
      Reset();
    }
    last_target_ns_ = target_ns;
  }

  static constexpr unsigned kMaxConsecutiveSkips = 8;
  int64_t last_target_ns_ = 0;
  int64_t frame_interval_ns_ = 0;
  double render_ns_ = 0;
  unsigned consecutive_skips_ = 0;
};

#endif  // BANGUMI_PLAYBACK_FRAME_SCHEDULER_H_
