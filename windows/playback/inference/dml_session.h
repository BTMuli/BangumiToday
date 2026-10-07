// Copyright (c) BangumiToday contributors. Licensed under the project MIT
// license.
#pragma once

#include <d3d11.h>
#include <d3d12.h>

#include <cstdint>
#include <filesystem>
#include <memory>

#include "interop.h"

namespace bangumi::inference {

// DirectML tensor execution only. YUV conversion, frame lifetime and the
// renderer handoff live in FrameConverter and FramePipeline. The session runs
// on the D3D12 device and queue owned by the interop context, so its work is
// ordered against the frame copies by the shared fence.
//
// Construct, Run and destroy on one native worker, never on Flutter's UI
// isolate. One instance is owned by one Player.
class DmlSession final {
 public:
  struct Options {
    // Diagnostics only: when set, ONNX Runtime writes a profiling JSON to this
    // path and EndPlacementProfiling() reports the file that was produced. It
    // is off by default because profiling adds per-node overhead.
    std::filesystem::path placement_profile;
    // ONNX Runtime log severity (0 verbose, 1 info, 2 warning, 3 error,
    // 4 fatal). Info level makes the runtime report how many nodes each
    // execution provider claimed, which is how node placement is checked.
    int log_severity = 2;
  };

  DmlSession(InteropContext& interop,
             const std::filesystem::path& runtime_directory,
             const std::filesystem::path& model, uint32_t width,
             uint32_t height, const Options& options = {});
  ~DmlSession();
  DmlSession(const DmlSession&) = delete;
  DmlSession& operator=(const DmlSession&) = delete;

  // Both tensors are FP16 RGB NCHW, batch=1, packed. The output is exactly 2x
  // the unrotated input. Resources stay on the playback adapter.
  ID3D12Resource* input() const;
  ID3D12Resource* output() const;
  uint64_t input_bytes() const;
  uint64_t output_bytes() const;
  uint32_t width() const;
  uint32_t height() const;
  LUID adapter_luid() const;

  // Submits one inference over the bound tensors on the shared queue. Runs may
  // overlap: the queue keeps them in submission order, so the caller only has
  // to order its own tensor writes on the GPU. The returned fence value must
  // complete before consuming the output or recycling its buffers.
  uint64_t Run();
  bool Complete(uint64_t ticket) const;
  void Wait(uint64_t ticket, uint32_t timeout_ms = 5000);

  // Stops placement profiling and returns the file that actually holds it;
  // empty when profiling was not enabled. Analyze it with
  // AnalyzePlacementProfile().
  std::filesystem::path EndPlacementProfiling();

 private:
  struct State;
  std::unique_ptr<State> state_;
};

}  // namespace bangumi::inference
