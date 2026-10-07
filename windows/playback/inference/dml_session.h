// Copyright (c) BangumiToday contributors. Licensed under the project MIT
// license.
#pragma once

#include <d3d11.h>
#include <d3d12.h>
#include <wrl/client.h>

#include <cstdint>
#include <filesystem>
#include <memory>

namespace bangumi::inference {

// GPU tensor execution only. YUV conversion and the mpv frame lifecycle are
// separate responsibilities. Construct, Run and destroy on a native worker,
// never on Flutter's UI isolate. One instance is owned by one Player.
class DmlSession final {
 public:
  DmlSession(const std::filesystem::path& runtime_directory,
             const std::filesystem::path& model, ID3D11Device* playback_device,
             uint32_t width, uint32_t height);
  ~DmlSession();
  DmlSession(const DmlSession&) = delete;
  DmlSession& operator=(const DmlSession&) = delete;

  // Both tensors are FP16 RGB NCHW, batch=1. The output is exactly 2x the
  // unrotated input. Resources stay on the device used by the playback adapter.
  ID3D12Resource* input() const;
  ID3D12Resource* output() const;
  ID3D12Device* device() const;
  ID3D12CommandQueue* queue() const;
  uint64_t input_bytes() const;
  uint64_t output_bytes() const;
  LUID adapter_luid() const;

  // Work submitted on queue() before this call precedes inference. A returned
  // ticket must complete before consuming output or recycling input buffers.
  uint64_t Run();
  bool Complete(uint64_t ticket) const;
  void Wait(uint64_t ticket, uint32_t timeout_ms = 5000);

 private:
  struct State;
  std::unique_ptr<State> state_;
};

}  // namespace bangumi::inference
