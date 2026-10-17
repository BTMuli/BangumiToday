#pragma once
#include <d3d11.h>
#include <wrl/client.h>

#include <cstdint>
#include <stdexcept>
#include <string>

namespace playback_gpu_test {
using Microsoft::WRL::ComPtr;

inline void Require(bool condition, const char* message) {
  if (!condition) throw std::runtime_error(message);
}
inline void Check(HRESULT result) {
  Require(SUCCEEDED(result), "D3D operation failed");
}

template <class Expected>
void CheckPixels(ID3D11Device* device, ID3D11DeviceContext* context,
                 ID3D11Texture2D* texture, Expected expected) {
  D3D11_TEXTURE2D_DESC description{};
  texture->GetDesc(&description);
  description.Usage = D3D11_USAGE_STAGING;
  description.BindFlags = 0;
  description.MiscFlags = 0;
  description.CPUAccessFlags = D3D11_CPU_ACCESS_READ;
  ComPtr<ID3D11Texture2D> staging;
  Check(device->CreateTexture2D(&description, nullptr, &staging));
  context->CopyResource(staging.Get(), texture);
  D3D11_MAPPED_SUBRESOURCE mapped{};
  Check(context->Map(staging.Get(), 0, D3D11_MAP_READ, 0, &mapped));
  bool valid = true;
  UINT bad_x = 0, bad_y = 0;
  uint32_t actual = 0, wanted = 0;
  for (UINT y = 0; valid && y < description.Height; ++y) {
    const auto row = reinterpret_cast<const uint32_t*>(
        static_cast<const uint8_t*>(mapped.pData) + y * mapped.RowPitch);
    for (UINT x = 0; x < description.Width; ++x) {
      if (row[x] != expected(x, y)) {
        valid = false;
        bad_x = x;
        bad_y = y;
        actual = row[x];
        wanted = expected(x, y);
        break;
      }
    }
  }
  context->Unmap(staging.Get(), 0);
  if (!valid)
    throw std::runtime_error("Snapshot mismatch at " + std::to_string(bad_x) +
        "," + std::to_string(bad_y) + " actual=" + std::to_string(actual) +
        " expected=" + std::to_string(wanted));
}

inline void CheckPixels(ID3D11Device* device, ID3D11DeviceContext* context,
                         ID3D11Texture2D* texture, uint32_t expected) {
  CheckPixels(device, context, texture, [expected](UINT, UINT) { return expected; });
}
}  // namespace playback_gpu_test
