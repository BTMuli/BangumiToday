#include <cstdint>
#include <iostream>
#include <limits>
#include <stdexcept>

#include "frame_scheduler.h"

namespace {
constexpr int64_t k24Fps = 41'708'375;
constexpr int64_t k30Fps = 33'333'333;
constexpr int64_t k60Fps = 16'666'667;

void Require(bool condition, const char* message) {
  if (!condition) throw std::runtime_error(message);
}

PlaybackFrameInfo Frame(int64_t target) {
  return {PlaybackFrameInfo::kPresent, target};
}

struct Playback {
  PlaybackFrameScheduler scheduler;
  int64_t target = 1'000'000'000;

  bool Next(int64_t interval, int64_t late, double render_ms) {
    target += interval;
    const auto frame = Frame(target);
    const bool skipped =
        scheduler.ShouldSkip(frame, target + late, false, false);
    if (!skipped) scheduler.RecordRender(frame, render_ms);
    return skipped;
  }

  void Warm(int64_t interval, double render_ms) {
    for (int i = 0; i < 16; ++i)
      Require(!Next(interval, 100'000, render_ms), "Warm frames were skipped");
  }
};

void CheckOrdinaryPlayback() {
  Playback playback;
  playback.Warm(k30Fps, 3.6);
  // Observed ordinary 30 FPS playback: callbacks were late, but rendering was
  // cheap and there was still time to display the frame before its successor.
  for (const int64_t late : {12'050'000LL, 6'120'000LL, 9'280'000LL})
    Require(!playback.Next(k30Fps, late, 3.6),
            "Ordinary playback lost a useful, slightly late frame");
  Require(playback.Next(k30Fps, 30'000'000, 3.6),
          "A frame that cannot fit its render cost was retained");
  Require(playback.Next(k30Fps, k30Fps, 3.6),
          "A whole-frame-late image was retained");
  Require(!playback.Next(k30Fps, 0, 3.6),
          "Playback did not recover after skips");

  Playback fractional;
  fractional.Warm(k24Fps, 3.6);  // 24000/1001 FPS.
  Require(!fractional.Next(k24Fps, 20'000'000, 3.6),
          "Fractional cadence used the 30 FPS budget");
  Require(fractional.Next(k24Fps, k24Fps, 3.6),
          "Fractional cadence did not discard an expired frame");
}

void CheckRenderCostAndOverload() {
  Playback cheap;
  cheap.Warm(k60Fps, 3.6);
  Require(!cheap.Next(k60Fps, 12'000'000, 3.6),
          "A cheap 60 FPS frame was skipped too early");
  Require(cheap.Next(k60Fps, 14'000'000, 3.6),
          "The render cost was not reserved at 60 FPS");

  Playback expensive;
  expensive.Warm(k60Fps, 12);
  Require(expensive.Next(k60Fps, 9'000'000, 12),
          "A costly 60 FPS frame ignored its render budget");

  Playback overloaded;
  overloaded.Warm(k30Fps, 50);
  Require(!overloaded.Next(k30Fps, 6'000'000, 50),
          "Slow rendering starved every slightly late frame");
  for (int i = 0; i < 8; ++i)
    Require(overloaded.Next(k30Fps, 100'000'000, 50),
            "Severely overdue frames were not skipped");
  Require(!overloaded.Next(k30Fps, 100'000'000, 50),
          "The maximum skip burst stopped making progress");
  Require(overloaded.Next(k30Fps, 100'000'000, 50),
          "Skipping did not resume after the progress frame");

  Playback spike;
  spike.Warm(k30Fps, 3.6);
  Require(!spike.Next(k30Fps, 0, 200), "An on-time slow frame was skipped");
  Require(!spike.Next(k30Fps, 12'000'000, 3.6),
          "One render spike caused ordinary frames to be discarded");

  // Skipping a frame must not change the cadence learned from target times.
  Playback gap;
  gap.Warm(k30Fps, 3.6);
  Require(gap.Next(k30Fps, 100'000'000, 3.6),
          "An expired frame was retained");
  Require(!gap.Next(k30Fps, 12'000'000, 3.6),
          "A skipped frame changed the learned cadence");
}

void CheckCadenceChanges() {
  Playback playback;
  playback.Warm(k30Fps, 26);
  Require(!playback.Next(k60Fps, 12'000'000, 3.6),
          "A speed change retained the old expensive render estimate");
  Require(!playback.Next(k60Fps, 12'000'000, 3.6),
          "The faster cadence did not calibrate");
  Require(playback.Next(k60Fps, 14'000'000, 3.6),
          "A faster cadence retained the old, longer frame budget");
  Require(!playback.Next(k24Fps, 25'000'000, 3.6),
          "A slower cadence retained the short frame budget");

  // Triple-speed 24 FPS uses a 13.9 ms cadence. A frame 6 ms late still fits,
  // while a frame that leaves less than one render cost of headroom does not.
  Playback accelerated;
  accelerated.Warm(k24Fps, 3.6);
  const int64_t threeTimes = k24Fps / 3;
  Require(!accelerated.Next(threeTimes, 6'000'000, 3.6),
          "3x playback discarded a frame with enough remaining time");
  Require(accelerated.Next(threeTimes, 11'000'000, 3.6),
          "3x playback ignored its shorter frame budget");
  Require(!accelerated.Next(k24Fps, 12'000'000, 3.6),
          "Returning to 1x retained the 3x budget");

  playback.target += 10'000'000'000;
  auto frame = Frame(playback.target);
  Require(!playback.scheduler.ShouldSkip(frame, frame.target_time + 12'000'000,
                                          false, false),
          "Pause/resume retained a stale timing estimate");
  playback.scheduler.RecordRender(frame, 200);
  Require(!playback.Next(k30Fps, 12'000'000, 3.6),
          "Pause time was learned as render demand");

  playback.target = 500'000'000;
  frame = Frame(playback.target);
  Require(!playback.scheduler.ShouldSkip(frame, frame.target_time + 12'000'000,
                                         false, false),
          "A backwards clock retained the previous cadence");
  Require(!playback.Next(k30Fps, 12'000'000, 3.6),
          "Playback did not recalibrate after a backwards clock");
}

void CheckProtectedFramesAndInvalidSamples() {
  Playback playback;
  playback.Warm(k30Fps, 3.6);
  for (const uint64_t flag :
       {PlaybackFrameInfo::kRedraw, PlaybackFrameInfo::kRepeat,
        PlaybackFrameInfo::kBlockVsync}) {
    auto frame = Frame(playback.target + 100'000'000);
    frame.flags |= flag;
    Require(!playback.scheduler.ShouldSkip(
                frame, frame.target_time + 500'000'000, false, false),
            "An untimed frame was skipped");
    playback.scheduler.RecordRender(frame, 500);
  }
  auto frame = Frame(0);
  Require(!playback.scheduler.ShouldSkip(frame, 1'000'000'000, false, false),
          "A frame without a target was skipped");
  frame = {0, playback.target};
  Require(!playback.scheduler.ShouldSkip(frame, frame.target_time + 500'000'000,
                                         false, false),
          "A frame without PRESENT was skipped");
  frame = Frame(playback.target);
  for (const double elapsed :
       {0.0, -1.0, std::numeric_limits<double>::infinity(),
        std::numeric_limits<double>::quiet_NaN()})
    playback.scheduler.RecordRender(frame, elapsed);
  Require(!playback.Next(k30Fps, 12'000'000, 3.6),
          "Invalid/untimed measurements changed the render estimate");

  playback.target += k30Fps;
  frame = Frame(playback.target);
  Require(!playback.scheduler.ShouldSkip(frame, frame.target_time + 500'000'000,
                                         true, false),
          "A forced frame was skipped");
  Require(!playback.scheduler.ShouldSkip(frame, frame.target_time + 500'000'000,
                                         false, true),
          "The first resized frame was skipped");
  Require(!playback.Next(k30Fps, 12'000'000, 3.6),
          "The first resized frame retained the old estimate");

  Playback unknown;
  Require(!unknown.scheduler.ShouldSkip(Frame(1'000'000'000), 2'000'000'000,
                                        false, false),
          "A scheduler without a known cadence discarded its first frame");
}
}  // namespace

int main() {
  try {
    CheckOrdinaryPlayback();
    CheckRenderCostAndOverload();
    CheckCadenceChanges();
    CheckProtectedFramesAndInvalidSamples();
    std::cout << "PASS: ordinary playback jitter, render budgets, overload "
                 "progress, cadence changes and protected frames\n";
    return 0;
  } catch (const std::exception& error) {
    std::cerr << error.what() << '\n';
    return 1;
  }
}
