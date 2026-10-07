// Copyright (c) BangumiToday contributors. Licensed under the project MIT
// license.
#pragma once
#include <d3d11.h>

#include <cstdint>
#include <string>

namespace bangumi::inference {
struct GpuCapabilities {
  std::wstring name;
  LUID luid{};
  uint32_t vendor = 0;
  bool directml_device = false;
  int cuda_device = -1;
  int compute_major = 0;
  int compute_minor = 0;
  int cuda_driver_version = 0;
  std::string cuda_reason;
};

// Pass ANGLE/mpv's actual D3D11 device, never a guessed adapter ordinal. This
// only queries the system driver; it neither loads TRT nor downloads resources.
// Device capability does not imply an accepted frame bridge or realtime speed.
GpuCapabilities QueryGpuCapabilities(ID3D11Device* playback_device);
}  // namespace bangumi::inference
