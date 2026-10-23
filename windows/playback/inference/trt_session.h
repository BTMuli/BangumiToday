// Copyright (c) BangumiToday contributors. Licensed under the project MIT.
#pragma once
#include <d3d11.h>

#include <filesystem>
#include <functional>
#include <memory>
#include <string>

#include "gpu_capabilities.h"

namespace bangumi::inference {
struct TrtResources;
// One native playback worker owns a session. Construction validates the exact
// engine contract and warms it before the session can be activated.
class TrtSession final {
 public:
  TrtSession(std::shared_ptr<TrtResources> resources,
             const std::filesystem::path& engine, const GpuCapabilities& gpu,
             uint32_t width, uint32_t height,
             const std::function<void()>& checkpoint = {},
             const std::function<void(const char*)>& progress = {});
  ~TrtSession();
  TrtSession(const TrtSession&) = delete;
  TrtSession& operator=(const TrtSession&) = delete;
  // Private R16_FLOAT input texture of width x (height * 3) and a DEFAULT
  // R32_UINT D3D11 buffer of (width * 2) x (height * 6) FP16 planes, both on
  // the same playback device. TensorRT writes the model output directly into
  // the CUDA-mapped buffer; the converter reads it without an unpack copy.
  // The converter's graphics accesses are ordered by CUDA map/unmap in Run.
  void Attach(ID3D11Texture2D* input, ID3D11Buffer* output);
  // Retire this attachment while keeping the validated engine, execution
  // context and input allocation. A faulted session is never returned to cache.
  bool Detach() noexcept;
  void Run(ID3D11DeviceContext* context, bool measure);
  struct GpuTiming {
    double input_copy_ms = 0;
    double inference_ms = 0;
    double output_copy_ms = 0;
    double total_ms = 0;
  };
  // Consume the requested frame's measurement without waiting. No later Run
  // may replace its events until this returns true.
  bool ReadGpuTiming(GpuTiming* timing);
  // Host API timings, separate from asynchronous GPU event measurements.
  struct SubmissionTiming {
    double map_ms = 0;
    double unmap_ms = 0;
  };
  SubmissionTiming last_submission_timing() const;
  bool uses_cuda_graph() const;

 private:
  struct State;
  std::unique_ptr<State> state_;
};
}  // namespace bangumi::inference
