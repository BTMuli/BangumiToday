// Copyright (c) BangumiToday contributors. Licensed under the project MIT
// license.
#include "gpu_capabilities.h"

#include <Windows.h>
#include <d3d12.h>
#include <dxgi1_4.h>
#include <wrl/client.h>

#include <cstring>
#include <stdexcept>

namespace bangumi::inference {
GpuCapabilities QueryGpuCapabilities(ID3D11Device* playback_device) {
  using Microsoft::WRL::ComPtr;
  if (!playback_device) throw std::invalid_argument("Playback device is null");
  ComPtr<IDXGIDevice> dxgi_device;
  ComPtr<IDXGIAdapter> adapter;
  DXGI_ADAPTER_DESC description{};
  if (FAILED(playback_device->QueryInterface(IID_PPV_ARGS(&dxgi_device))) ||
      FAILED(dxgi_device->GetAdapter(&adapter)) ||
      FAILED(adapter->GetDesc(&description))) {
    throw std::runtime_error("Cannot identify the actual playback adapter");
  }
  GpuCapabilities result;
  result.name = description.Description;
  result.luid = description.AdapterLuid;
  result.vendor = description.VendorId;
  ComPtr<IDXGIAdapter1> adapter1;
  DXGI_ADAPTER_DESC1 flags{};
  if (FAILED(adapter.As(&adapter1)) || FAILED(adapter1->GetDesc1(&flags))) {
    throw std::runtime_error("Cannot identify playback adapter flags");
  }
  if (flags.Flags & DXGI_ADAPTER_FLAG_SOFTWARE) {
    result.cuda_reason = "software_playback_adapter";
    return result;
  }
  result.directml_device = SUCCEEDED(D3D12CreateDevice(
      adapter.Get(), D3D_FEATURE_LEVEL_11_0, __uuidof(ID3D12Device), nullptr));
  if (result.vendor != 0x10de) {
    result.cuda_reason = "playback_adapter_is_not_nvidia";
    return result;
  }
  // nvcuda.dll belongs to the installed graphics driver. Never bundle it or
  // load it from the application directory, PATH or a user-installed Toolkit.
  struct Driver final {
    HMODULE module =
        LoadLibraryExW(L"nvcuda.dll", nullptr, LOAD_LIBRARY_SEARCH_SYSTEM32);
    ~Driver() {
      if (module) FreeLibrary(module);
    }
  } driver;
  if (!driver.module) {
    result.cuda_reason = "nvidia_driver_api_unavailable";
    return result;
  }
  using Init = int(WINAPI*)(unsigned);
  using MapD3D11 = int(WINAPI*)(int*, IDXGIAdapter*);
  using DeviceLuid = int(WINAPI*)(char*, unsigned*, int);
  using ComputeCapability = int(WINAPI*)(int*, int*, int);
  using DriverVersion = int(WINAPI*)(int*);
  const auto init =
      reinterpret_cast<Init>(GetProcAddress(driver.module, "cuInit"));
  const auto map = reinterpret_cast<MapD3D11>(
      GetProcAddress(driver.module, "cuD3D11GetDevice"));
  const auto luid = reinterpret_cast<DeviceLuid>(
      GetProcAddress(driver.module, "cuDeviceGetLuid"));
  const auto compute = reinterpret_cast<ComputeCapability>(
      GetProcAddress(driver.module, "cuDeviceComputeCapability"));
  const auto version = reinterpret_cast<DriverVersion>(
      GetProcAddress(driver.module, "cuDriverGetVersion"));
  if (!init || !map || !luid || !compute || !version || init(0) != 0) {
    result.cuda_reason = "nvidia_driver_api_incomplete_or_init_failed";
    return result;
  }
  int device = -1;
  if (map(&device, adapter.Get()) != 0) {
    result.cuda_reason = "cuda_d3d11_adapter_mapping_failed";
    return result;
  }
  char cuda_luid[sizeof(LUID)]{};
  unsigned node_mask = 0;
  if (luid(cuda_luid, &node_mask, device) != 0 || node_mask != 1 ||
      std::memcmp(cuda_luid, &result.luid, sizeof(LUID)) != 0) {
    result.cuda_reason = "cuda_d3d11_adapter_luid_mismatch_or_multi_node";
    return result;
  }
  if (compute(&result.compute_major, &result.compute_minor, device) != 0 ||
      version(&result.cuda_driver_version) != 0) {
    result.cuda_reason = "cuda_architecture_query_failed";
    return result;
  }
  result.cuda_device = device;
  return result;
}
}  // namespace bangumi::inference
