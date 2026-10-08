// Copyright (c) BangumiToday contributors. Licensed under the project MIT.
#pragma once
#include <d3d11.h>

#include <filesystem>
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
             uint32_t width, uint32_t height);
  ~TrtSession();
  TrtSession(const TrtSession&) = delete;
  TrtSession& operator=(const TrtSession&) = delete;
  void Attach(ID3D11Texture2D* input, ID3D11Texture2D* output);
  void Run(ID3D11DeviceContext* context);
  double last_gpu_ms() const;

 private:
  struct State;
  std::unique_ptr<State> state_;
};
}  // namespace bangumi::inference
