// Copyright (c) BangumiToday contributors. Licensed under the project MIT.
#pragma once
#include <Windows.h>
#include <d3d11.h>

// cudaD3D11.h requires D3D11 declarations before it is included.
#include <cuda.h>
#include <cudaD3D11.h>

#include <stdexcept>
#include <string>

namespace bangumi::inference {
// Only the system driver is loaded. No CUDA import library, Toolkit or PATH
// lookup is used by the base player or by the optional TensorRT path.
class CudaApi final {
 public:
  CudaApi();
  ~CudaApi();
  CudaApi(const CudaApi&) = delete;
  CudaApi& operator=(const CudaApi&) = delete;
  static void Check(CUresult result, const char* operation);

// clang-format off
#define BT_CUDA_FUNCTIONS(X) \
  X(cuInit) \
  X(cuDevicePrimaryCtxRetain) X(cuDevicePrimaryCtxRelease) \
  X(cuCtxPushCurrent) X(cuCtxPopCurrent) \
  X(cuStreamCreate) X(cuStreamDestroy) \
  X(cuMemAlloc) X(cuMemFree) X(cuMemsetD8Async) X(cuMemcpy2DAsync) \
  X(cuGraphicsD3D11RegisterResource) X(cuGraphicsUnregisterResource) \
  X(cuGraphicsMapResources) X(cuGraphicsUnmapResources) \
  X(cuGraphicsSubResourceGetMappedArray) \
  X(cuEventCreate) X(cuEventDestroy) X(cuEventRecord) X(cuEventQuery) \
  X(cuEventElapsedTime) X(cuDeviceGetUuid)
// clang-format on
#define BT_CUDA_DECLARE(name) decltype(&name) name = nullptr;
  BT_CUDA_FUNCTIONS(BT_CUDA_DECLARE)
#undef BT_CUDA_DECLARE
 private:
  HMODULE module_ = nullptr;
};

class CudaScope final {
 public:
  CudaScope(CudaApi& api, CUcontext context) : api_(api) {
    CudaApi::Check(api_.cuCtxPushCurrent(context), "Enter CUDA context");
  }
  ~CudaScope() {
    CUcontext previous = nullptr;
    api_.cuCtxPopCurrent(&previous);
  }

 private:
  CudaApi& api_;
};
}  // namespace bangumi::inference
