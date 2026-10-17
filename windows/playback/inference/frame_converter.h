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
  // `direct_ml` selects the shared-texture storage the D3D12 session copies
  // from. Otherwise the model input stays a private CUDA-mapped texture and the
  // model output becomes a CUDA-mapped D3D11 buffer that TensorRT writes
  // directly, removing the unpack copy back into a texture.
  static std::unique_ptr<FrameConverter> Create(
      ID3D11Device* device, const FramePlan& plan, const ColorConversion& color,
      std::string* reason, bool direct_ml = true);
  ~FrameConverter();
  FrameConverter(const FrameConverter&) = delete;
  FrameConverter& operator=(const FrameConverter&) = delete;

  // Decoder plane views (R8/R8G8 or R16/R16G16) -> planar FP16 RGB model
  // input. The caller must have made the planes safe to read on the GPU.
  void ConvertToPlanarRgb(ID3D11DeviceContext* context,
                          ID3D11ShaderResourceView* luma,
                          ID3D11ShaderResourceView* chroma);
  // Model output planes -> luma and chroma output planes. The DirectML session
  // must have filled the shared texture, or TensorRT the mapped buffer, first.
  void ConvertFromPlanarRgb(ID3D11DeviceContext* context);

  ID3D11Texture2D* planar_rgb() const;
  // DirectML only; null on the TensorRT path.
  ID3D11Texture2D* model_output_texture() const;
  // TensorRT only; null on the DirectML path.
  ID3D11Buffer* model_output_buffer() const;
  ID3D11Texture2D* out_luma() const;
  ID3D11Texture2D* out_chroma() const;

 private:
  FrameConverter() = default;
  struct State;
  std::unique_ptr<State> state_;
};

}  // namespace bangumi::inference
