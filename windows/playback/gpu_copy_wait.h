#ifndef BANGUMI_PLAYBACK_GPU_COPY_WAIT_H_
#define BANGUMI_PLAYBACK_GPU_COPY_WAIT_H_

#include <windows.h>
#include <d3d11_3.h>
#include <wrl/client.h>

// D3D completion events wake the worker early. A private high-resolution timer
// also bounds query rechecks: Flush1's batch event can arrive after the copy's
// own query is ready. Neither path changes timer resolution or busy-waits.
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
    // Waiting for the whole flush batch for 100 ms can miss a ready video
    // frame's deadline. The caller still verifies GetData after every wakeup.
    const DWORD interval_ms = timeout_ms < 2 ? timeout_ms : 2;
    HANDLE handles[2]{};
    DWORD count = 0;
    if (event_pending_) handles[count++] = completion_;
    LARGE_INTEGER due{};
    due.QuadPart = -10'000 * static_cast<LONGLONG>(interval_ms);
    if (timer_ && ::SetWaitableTimer(timer_, &due, 0, nullptr, nullptr, FALSE))
      handles[count++] = timer_;
    if (count && ::WaitForMultipleObjects(count, handles, FALSE, interval_ms) !=
                     WAIT_FAILED)
      return;
    event_pending_ = false;
    ::Sleep(interval_ms);
  }

 private:
  Microsoft::WRL::ComPtr<ID3D11DeviceContext3> context3_;
  HANDLE completion_ = nullptr;
  bool event_pending_ = false;
  HANDLE timer_ = nullptr;
};

#endif  // BANGUMI_PLAYBACK_GPU_COPY_WAIT_H_
