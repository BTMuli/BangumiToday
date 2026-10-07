// Copyright (c) BangumiToday contributors. Licensed under the project MIT
// license.
//
// Cross-API plumbing for the AnimeJaNai bridge: one D3D12 device and command
// queue on the playback adapter plus a shared fence that orders D3D11 work
// (decoder planes and conversion shaders) against D3D12 work (tensor copies and
// DirectML runs). Nothing here reads pixels back to the CPU.
#pragma once

#include <d3d11_4.h>
#include <d3d12.h>
#include <wrl/client.h>

#include <cstdint>
#include <functional>
#include <memory>
#include <vector>

namespace bangumi::inference {

class InteropContext final {
 public:
  // Fails when the playback adapter has no D3D12 device or cannot share
  // fences. Create, use and destroy on one native worker thread.
  static std::unique_ptr<InteropContext> Create(ID3D11Device* playback_device);
  ~InteropContext();
  InteropContext(const InteropContext&) = delete;
  InteropContext& operator=(const InteropContext&) = delete;

  ID3D12Device* device() const;
  ID3D12CommandQueue* queue() const;
  // The shared fence. Holding a reference keeps completion polling valid even
  // if this context is destroyed first.
  ID3D12Fence* fence() const;
  LUID adapter_luid() const;

  // Records one batch and submits it on the shared queue. When `wait_value` is
  // non-zero the queue waits for it before running the batch. The returned
  // fence value must complete before anything consuming the batch results runs.
  uint64_t Submit(
      uint64_t wait_value,
      const std::function<void(ID3D12GraphicsCommandList*)>& record);
  // Advances the shared fence without recording work; used to publish work the
  // DirectML session submitted on the same queue.
  uint64_t SignalQueue();
  // Advances the shared fence from the D3D11 immediate context (GPU-side only).
  uint64_t SignalFromD3D11(ID3D11DeviceContext4* context4);
  // Makes later D3D11 work wait for a value on the GPU; never blocks the CPU.
  void WaitOnD3D11(ID3D11DeviceContext4* context4, uint64_t value);

  bool Complete(uint64_t value) const;
  // Blocking wait for verification and teardown only.
  void Wait(uint64_t value, uint32_t timeout_ms = 10000);
  uint64_t last_submitted() const;

  // GPU timestamps measured on the shared queue. `slot` indexes a fixed ring
  // owned by this context; record timestamps inside a batch and resolve them in
  // the last batch of the frame, then read them once that fence completed.
  static constexpr uint32_t kTimestampSlots = 16;
  static constexpr uint32_t kTimestampBuffers = 4;
  bool timestamps_supported() const;
  void WriteTimestamp(ID3D12GraphicsCommandList* list, uint32_t slot);
  void ResolveTimestamps(ID3D12GraphicsCommandList* list, uint32_t first_slot,
                         uint32_t count, uint32_t buffer);
  // Returns false while the measurement is not ready yet.
  bool ReadTimestamps(uint64_t value, uint32_t buffer, uint32_t count,
                      std::vector<uint64_t>* ticks);
  // Converts a tick delta into milliseconds (0 when timestamps are missing).
  double MillisecondsBetween(uint64_t begin, uint64_t end) const;

 private:
  InteropContext() = default;
  struct State;
  std::unique_ptr<State> state_;
};

}  // namespace bangumi::inference
