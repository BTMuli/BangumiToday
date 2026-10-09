// Copyright (c) BangumiToday contributors. Licensed under the project MIT
// license.
#include "frame_budget.h"

#include <algorithm>
#include <cmath>
#include <stdexcept>

namespace bangumi::inference {
namespace {
// Caps the samples kept for one window so a very fast GPU cannot grow the
// buffer without bound; far more than a two-second window can hold.
constexpr size_t kMaximumWindowSamples = 4096;
}  // namespace

void FrameBudgetMonitor::Configure(double frames_per_second) {
  if (!(frames_per_second >= 0.0) || !std::isfinite(frames_per_second))
    throw std::invalid_argument("Invalid frame rate for the budget monitor");
  budget_ms_ = frames_per_second > 0.0 ? 1000.0 / frames_per_second : 0.0;
  Reset();
}

void FrameBudgetMonitor::AddFrame(double gpu_ms, double wall_ms) {
  if (!std::isfinite(gpu_ms) || gpu_ms < 0.0 || !std::isfinite(wall_ms) ||
      wall_ms < 0.0)
    throw std::invalid_argument("Invalid frame timing");
  if (window_gpu_ms_.size() < kMaximumWindowSamples)
    window_gpu_ms_.push_back(gpu_ms);
  window_elapsed_ms_ += wall_ms;
  if (window_elapsed_ms_ >= kWindowMs) CloseWindow();
}

void FrameBudgetMonitor::ReportDropRate(double percent) {
  if (!std::isfinite(percent) || percent < 0.0)
    throw std::invalid_argument("Invalid drop rate");
  drop_rate_percent_ = percent;
}

void FrameBudgetMonitor::Reset() {
  window_elapsed_ms_ = 0;
  window_gpu_ms_.clear();
  consecutive_over_budget_ = 0;
  drop_rate_percent_ = 0;
  snapshot_ = Snapshot{};
  snapshot_.budget_ms = budget_ms_;
}

void FrameBudgetMonitor::CloseWindow() {
  const uint64_t frames = window_gpu_ms_.size();
  const bool valid = frames >= kMinimumWindowFrames;
  double median = 0;
  double p95 = 0;
  if (frames > 0) {
    std::vector<double> sorted = window_gpu_ms_;
    std::sort(sorted.begin(), sorted.end());
    median = sorted[sorted.size() / 2];
    p95 = sorted[static_cast<size_t>(std::min<double>(
        static_cast<double>(sorted.size() - 1),
        std::floor(static_cast<double>(sorted.size()) * 0.95)))];
  }
  const double minimum_fps =
      budget_ms_ > 0.0 ? std::min(5.0, 250.0 / budget_ms_) : 0.0;
  const bool starved = minimum_fps > 0.0 && window_elapsed_ms_ > 0.0 &&
                       frames * 1000.0 / window_elapsed_ms_ < minimum_fps;
  // Successful-frame requirements must not suppress sustained low throughput.
  const bool over_budget =
      starved || (valid && ((budget_ms_ > 0.0 && median > budget_ms_) ||
                            drop_rate_percent_ > kMaximumDropRatePercent));
  if (valid || starved) {
    if (over_budget) {
      const auto windows = static_cast<uint32_t>(std::min<double>(
          kOverBudgetWindowsBeforeFallback,
          std::max(1.0, std::floor(window_elapsed_ms_ / kWindowMs))));
      consecutive_over_budget_ = std::min(kOverBudgetWindowsBeforeFallback,
                                          consecutive_over_budget_ + windows);
    } else {
      consecutive_over_budget_ = 0;
    }
  } else {
    consecutive_over_budget_ = 0;
  }
  snapshot_.budget_ms = budget_ms_;
  snapshot_.median_gpu_ms = median;
  snapshot_.p95_gpu_ms = p95;
  snapshot_.drop_rate_percent = drop_rate_percent_;
  snapshot_.window_frames = frames;
  snapshot_.window_elapsed_ms = window_elapsed_ms_;
  snapshot_.window_valid = valid;
  snapshot_.low_throughput = starved;
  snapshot_.consecutive_over_budget_windows = consecutive_over_budget_;
  snapshot_.over_budget = over_budget;
  snapshot_.fallback_recommended =
      consecutive_over_budget_ >= kOverBudgetWindowsBeforeFallback;
  window_elapsed_ms_ = 0;
  window_gpu_ms_.clear();
}

FrameBudgetMonitor::Snapshot FrameBudgetMonitor::snapshot() const {
  Snapshot result = snapshot_;
  result.budget_ms = budget_ms_;
  return result;
}

}  // namespace bangumi::inference
