// Copyright (c) BangumiToday contributors. Licensed under the project MIT.
#include "cuda_api.h"

namespace bangumi::inference {
void CudaApi::Check(CUresult result, const char* operation) {
  if (result != CUDA_SUCCESS)
    throw std::runtime_error(std::string(operation) + ": CUDA=" +
                             std::to_string(static_cast<int>(result)));
}
CudaApi::CudaApi() {
  module_ =
      LoadLibraryExW(L"nvcuda.dll", nullptr, LOAD_LIBRARY_SEARCH_SYSTEM32);
  if (!module_) throw std::runtime_error("NVIDIA system driver is unavailable");
  try {
    // CUDA headers alias the versioned ABI names (e.g. cuMemAlloc_v2).
#define BT_CUDA_STRING_IMPL(name) #name
#define BT_CUDA_STRING(name) BT_CUDA_STRING_IMPL(name)
#define BT_CUDA_LOAD(name)                            \
  name = reinterpret_cast<decltype(name)>(            \
      GetProcAddress(module_, BT_CUDA_STRING(name))); \
  if (!name) throw std::runtime_error("Missing CUDA driver API: " #name);
    BT_CUDA_FUNCTIONS(BT_CUDA_LOAD)
#undef BT_CUDA_LOAD
#undef BT_CUDA_STRING
#undef BT_CUDA_STRING_IMPL
    Check(cuInit(0), "Initialize CUDA driver");
  } catch (...) {
    FreeLibrary(module_);
    module_ = nullptr;
    throw;
  }
}
CudaApi::~CudaApi() {
  if (module_) FreeLibrary(module_);
}
}  // namespace bangumi::inference
