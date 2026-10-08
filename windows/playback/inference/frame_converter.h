// Copyright (c) BangumiToday contributors. Licensed under the project MIT
// license.
//
// D3D11 half of the frame bridge. Stage 1 turns decoder plane views into
// planar FP16 RGB for the model; stage 2 turns the model's 2x output into
// limited-range luma and 4:2:0 chroma planes of the visible output size. All
// colour work stays on the playback device; the D3D12 side only copies these
// shared textures to and from the DirectML tensors. TensorRT maps private RGB
// textures directly through CUDA; only the output YUV planes stay shared.
#pragma once

#include <d3d11.h>
#include <wrl/client.h>

#include <memory>
#include <string>

#include "frame_contract.h"

namespace bangumi::inference {

class FrameConverter final {
 public:
  // Returns nullptr when the playback device cannot run the verified path;
  // `reason` then carries a short user-facing explanation.
  // DirectML needs shared RGB textures; TensorRT registers private RGB textures
  // with CUDA so no additional D3D11 texture copies are needed each frame.
  static std::unique_ptr<FrameConverter> Create(
      ID3D11Device* device, const FramePlan& plan, const ColorConversion& color,
      std::string* reason, bool share_model_textures = true);
  ~FrameConverter();
  FrameConverter(const FrameConverter&) = delete;
  FrameConverter& operator=(const FrameConverter&) = delete;

  // Decoder plane views (R8/R8G8 or R16/R16G16) -> planar FP16 RGB model
  // input. The caller must have made the planes safe to read on the GPU.
  void ConvertToPlanarRgb(ID3D11DeviceContext* context,
                          ID3D11ShaderResourceView* luma,
                          ID3D11ShaderResourceView* chroma);
  // Model output planes -> luma and chroma output planes. The model output
  // texture must be filled and handed back by D3D12 or CUDA first.
  void ConvertFromPlanarRgb(ID3D11DeviceContext* context);

  ID3D11Texture2D* planar_rgb() const;
  ID3D11Texture2D* model_output_rgb() const;
  ID3D11Texture2D* out_luma() const;
  ID3D11Texture2D* out_chroma() const;

 private:
  FrameConverter() = default;
  struct State;
  std::unique_ptr<State> state_;
};

}  // namespace bangumi::inference
