#ifndef BANGUMI_PLAYBACK_GPU_COPY_WAIT_H_
#define BANGUMI_PLAYBACK_GPU_COPY_WAIT_H_

#include <windows.h>

// Sleep(1) can round a short GPU poll up to the system timer tick. A private
// high-resolution timer avoids that delay without changing process-wide timer
// resolution or spinning a CPU. Older Windows versions retain Sleep's behavior.
class PlaybackGpuCopyWait {
 public:
  PlaybackGpuCopyWait()
      : timer_(::CreateWaitableTimerExW(
            nullptr, nullptr, 0x00000002, TIMER_MODIFY_STATE | SYNCHRONIZE)) {}

  ~PlaybackGpuCopyWait() {
    if (timer_) ::CloseHandle(timer_);
  }

  PlaybackGpuCopyWait(const PlaybackGpuCopyWait&) = delete;
  PlaybackGpuCopyWait& operator=(const PlaybackGpuCopyWait&) = delete;

  void Wait() {
    LARGE_INTEGER due{};
    due.QuadPart = -10'000;  // Relative 1 ms, in 100 ns units.
    if (timer_ && ::SetWaitableTimer(timer_, &due, 0, nullptr, nullptr, FALSE) &&
        ::WaitForSingleObject(timer_, INFINITE) == WAIT_OBJECT_0)
      return;
    ::Sleep(1);
  }

 private:
  HANDLE timer_ = nullptr;
};

#endif  // BANGUMI_PLAYBACK_GPU_COPY_WAIT_H_
