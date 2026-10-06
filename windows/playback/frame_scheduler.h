#ifndef BANGUMI_PLAYBACK_FRAME_SCHEDULER_H_
#define BANGUMI_PLAYBACK_FRAME_SCHEDULER_H_

#include <render.h>

#include <cstdint>

// Consume overdue video frames without submitting more work to a busy GPU.
// The pinned libmpv runtime reports target_time in nanoseconds (despite the
// stale microsecond comment in render.h); compare it with mpv_get_time_ns.
class PlaybackFrameScheduler {
 public:
  bool ShouldSkip(const mpv_render_frame_info& frame, int64_t now_ns,
                  bool force, bool first_frame) {
    constexpr uint64_t untimed = MPV_RENDER_FRAME_INFO_REDRAW |
                                 MPV_RENDER_FRAME_INFO_REPEAT |
                                 MPV_RENDER_FRAME_INFO_BLOCK_VSYNC;
    const bool overdue = (frame.flags & MPV_RENDER_FRAME_INFO_PRESENT) &&
                         !(frame.flags & untimed) && frame.target_time > 0 &&
                         now_ns > frame.target_time &&
                         now_ns - frame.target_time > kLateToleranceNs;
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

 private:
  static constexpr int64_t kLateToleranceNs = 5'000'000;
  static constexpr unsigned kMaxConsecutiveSkips = 8;
  unsigned consecutive_skips_ = 0;
};

#endif  // BANGUMI_PLAYBACK_FRAME_SCHEDULER_H_
