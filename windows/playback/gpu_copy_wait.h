#ifndef BANGUMI_PLAYBACK_GPU_COPY_WAIT_H_
#define BANGUMI_PLAYBACK_GPU_COPY_WAIT_H_

#include <windows.h>
#include <d3d11_3.h>
#include <wrl/client.h>

// Modern D3D contexts wake the worker on GPU completion. Older contexts use a
// private high-resolution timer rather than rounding Sleep(1) up to a system
// timer tick, without changing process-wide timer resolution or spinning.
class PlaybackGpuCopyWait {
 public:
  PlaybackGpuCopyWait()
      : timer_(::CreateWaitableTimerExW(
            nullptr, nullptr, 0x00000002, TIMER_MODIFY_STATE | SYNCHRONIZE)) {}

  ~PlaybackGpuCopyWait() {
    if (completion_) ::CloseHandle(completion_);
    if (timer_) ::CloseHandle(timer_);
  }

  PlaybackGpuCopyWait(const PlaybackGpuCopyWait&) = delete;
  PlaybackGpuCopyWait& operator=(const PlaybackGpuCopyWait&) = delete;

  void SetContext(ID3D11DeviceContext* context) {
    event_pending_ = false;
    context3_.Reset();
    if (context && SUCCEEDED(context->QueryInterface(IID_PPV_ARGS(&context3_))) &&
        !completion_)
      completion_ = ::CreateEventW(nullptr, FALSE, FALSE, nullptr);
  }

  // GetData remains the completion check. The event only replaces the 1 ms
  // sleeps, so an early/stale wakeup can never publish an unfinished copy.
  void Flush(ID3D11DeviceContext* context) {
    if (context3_ && completion_ && ::ResetEvent(completion_)) {
      context3_->Flush1(D3D11_CONTEXT_TYPE_ALL, completion_);
      event_pending_ = true;
    } else {
      event_pending_ = false;
      context->Flush();
    }
  }

  void Wait(DWORD timeout_ms = 1) {
    if (event_pending_) {
      const auto result = ::WaitForSingleObject(completion_, timeout_ms);
      if (result == WAIT_OBJECT_0 || result == WAIT_TIMEOUT) return;
      event_pending_ = false;
    }
    LARGE_INTEGER due{};
    due.QuadPart = -10'000;  // Relative 1 ms, in 100 ns units.
    if (timer_ && ::SetWaitableTimer(timer_, &due, 0, nullptr, nullptr, FALSE) &&
        ::WaitForSingleObject(timer_, INFINITE) == WAIT_OBJECT_0)
      return;
    ::Sleep(1);
  }

 private:
  Microsoft::WRL::ComPtr<ID3D11DeviceContext3> context3_;
  HANDLE completion_ = nullptr;
  bool event_pending_ = false;
  HANDLE timer_ = nullptr;
};

#endif  // BANGUMI_PLAYBACK_GPU_COPY_WAIT_H_
