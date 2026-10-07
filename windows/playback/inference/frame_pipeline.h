// Copyright (c) BangumiToday contributors. Licensed under the project MIT
// license.
//
// One frame through the AnimeJaNai bridge:
//
//   D3D11 stage 1 -> D3D12 copy into the tensor -> DirectML run
//                 -> D3D12 copy out of the tensor -> D3D11 stage 2
//                 -> D3D12 plane copies into the shared NV12/P010 frame
//
// Every hand-off is ordered by the interop context's shared fence, and no step
// reads pixels back to the CPU. One frame is in flight at a time: the next
// submission waits for the previous ticket on the GPU and never blocks the
// calling thread.
#pragma once

#include <d3d11.h>
#include <d3d12.h>

#include <cstdint>
#include <filesystem>
#include <memory>
#include <string>

#include "frame_budget.h"
#include "frame_contract.h"

namespace bangumi::inference {

class FramePipeline final {
 public:
  struct Config {
    std::filesystem::path runtime_directory;
    std::filesystem::path model;
    FrameDescription frame;
    // Diagnostics only: enables ONNX Runtime placement profiling (see
    // DmlSession::Options). Off by default.
    std::filesystem::path placement_profile;
    // ONNX Runtime log severity (0 verbose .. 4 fatal). Info (1) makes the
    // runtime report which execution provider claimed the nodes.
    int log_severity = 2;
  };

  // Returns nullptr when the frame or the device is outside the verified
  // contract; `reason` then carries a short user-facing explanation.
  static std::unique_ptr<FramePipeline> Create(ID3D11Device* playback_device,
                                               const Config& config,
                                               std::string* reason);
  ~FramePipeline();
  FramePipeline(const FramePipeline&) = delete;
  FramePipeline& operator=(const FramePipeline&) = delete;

  // Submits one decoded frame. `luma` and `chroma` are the decoder texture's
  // plane views. When `output` is given, the finished 2x frame is written into
  // that texture instead of the pipeline's own frame; it must be an NV12/P010
  // texture of the planned output size created with the SHARED and
  // SHARED_NTHANDLE misc flags, which is how mpv's hardware frame pool creates
  // them. The returned ticket must complete before the output frame may be
  // sampled; use Complete/Wait for that.
  uint64_t Submit(ID3D11DeviceContext* context,
                  ID3D11ShaderResourceView* luma,
                  ID3D11ShaderResourceView* chroma,
                  ID3D11Texture2D* output = nullptr);

  // Shared 2x NV12/P010 frame, matching the decoded frame's format. The
  // renderer keeps the previous ticket's lifetime; the pipeline never writes it
  // before that ticket completes.
  ID3D11Texture2D* output_texture() const;
  // Diagnostics and verification: the planar FP16 RGB textures that carry the
  // model input and the model's 2x output.
  ID3D11Texture2D* model_input_texture() const;
  ID3D11Texture2D* model_output_texture() const;
  // Diagnostics only: the D3D12 device the bridge runs on. Never create or
  // destroy resources with it outside the pipeline's own worker thread.
  ID3D12Device* diagnostics_device() const;
  bool Complete(uint64_t ticket) const;
  void Wait(uint64_t ticket, uint32_t timeout_ms = 10000) const;
  const FramePlan& plan() const;

  // Wall-clock timing of the last submitted frame, for diagnostics only.
  struct Timing {
    double to_model_input_ms = 0;
    double to_model_output_ms = 0;
    double to_output_planes_ms = 0;
    double to_frame_ms = 0;
    // GPU timestamps of the last completed measurement. They cover the D3D12
    // copies and the DirectML run; the D3D11 conversion shaders run on the
    // playback context and are not included.
    double gpu_input_copy_ms = 0;
    double gpu_inference_ms = 0;
    double gpu_output_copy_ms = 0;
    double gpu_total_ms = 0;
    bool gpu_measured = false;
  };
  Timing last_timing() const;
  uint64_t submitted_frames() const;

  // Runtime performance protection. `frames_per_second` comes from the media;
  // without it the budget gate stays disabled and only statistics are kept.
  void ConfigureFrameRate(double frames_per_second);
  // Optional renderer feedback for the drop-rate half of the gate.
  void ReportDropRate(double percent);
  FrameBudgetMonitor::Snapshot performance() const;
  bool fallback_recommended() const;
  // Stops placement profiling and returns the file holding it; empty when the
  // pipeline was created without a placement profile path.
  std::filesystem::path EndPlacementProfiling();

 private:
  FramePipeline() = default;
  struct State;
  std::unique_ptr<State> state_;
};

}  // namespace bangumi::inference
