// Copyright (c) BangumiToday contributors. Licensed under the project MIT
// license.
//
// Runtime performance protection for the AnimeJaNai bridge. The plan requires
// falling back to normal playback once the upscaler keeps missing the frame
// budget: three consecutive two-second windows over budget or with severely
// reduced throughput. This file is pure logic so the decision can be
// checked without a GPU; FramePipeline feeds it GPU timings.
#pragma once

#include <cstdint>
#include <vector>

namespace bangumi::inference {

class FrameBudgetMonitor final {
 public:
  struct Snapshot {
    double budget_ms = 0;             // 0 when gating is disabled
    double median_gpu_ms = 0;         // last closed window
    double p95_gpu_ms = 0;
    double drop_rate_percent = 0;
    uint64_t window_frames = 0;
    double window_elapsed_ms = 0;
    bool window_valid = false;
    bool low_throughput = false;
    uint32_t consecutive_over_budget_windows = 0;
    bool over_budget = false;
    bool fallback_recommended = false;
  };

  // frames_per_second comes from the media's frame rate. Zero disables gating
  // (a window can then never be over budget).
  void Configure(double frames_per_second);
  // One finished frame: its GPU service time and the wall-clock time since the
  // previous frame. Both must be finite and non-negative. Long gaps not spent
  // on GPU work reset the windows: the bridge has no pause/buffering state.
  // Playback-aware throughput protection belongs to the Dart coordinator.
  void AddFrame(double gpu_ms, double wall_ms);
  // Optional renderer feedback (VO drop rate). The native bridge only measures
  // its own GPU work; the drop rate arrives from the playback integration.
  void ReportDropRate(double percent);
  void Reset();

  Snapshot snapshot() const;
  // Window length and validity rules, exposed for tests and diagnostics.
  static constexpr double kWindowMs = 2000.0;
  static constexpr uint64_t kMinimumWindowFrames = 10;
  static constexpr uint32_t kOverBudgetWindowsBeforeFallback = 3;
  static constexpr double kMaximumDropRatePercent = 1.0;

 private:
  void CloseWindow();

  double budget_ms_ = 0;
  double drop_rate_percent_ = 0;
  double window_elapsed_ms_ = 0;
  std::vector<double> window_gpu_ms_;
  uint32_t consecutive_over_budget_ = 0;
  Snapshot snapshot_;
};

}  // namespace bangumi::inference
