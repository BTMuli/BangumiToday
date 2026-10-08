// Copyright (c) BangumiToday contributors. Licensed under the project MIT.
#include "trt_session.h"

#include <NvInferRuntime.h>
#include <wrl/client.h>

#include <array>
#include <chrono>
#include <cstring>
#include <fstream>
#include <mutex>
#include <stdexcept>
#include <thread>
#include <vector>

#include "cuda_api.h"
#include "trt_engine_cache.h"

namespace bangumi::inference {
namespace {
using Microsoft::WRL::ComPtr;
using Clock = std::chrono::steady_clock;

struct Logger final : nvinfer1::ILogger {
  std::string error;
  void log(Severity severity, const char* message) noexcept override {
    if (severity <= Severity::kERROR) {
      try {
        error = message ? message : "TensorRT error";
      } catch (...) {
      }
    }
  }
};

struct Runtime final {
  std::shared_ptr<TrtResources> resources;
  std::vector<HMODULE> modules;
  using Create = void* (*)(void*, int32_t);
  Create create = nullptr;
  explicit Runtime(std::shared_ptr<TrtResources> value)
      : resources(std::move(value)) {
    try {
      for (const wchar_t* name : {L"cudart64_13.dll", L"nvinfer_11.dll"}) {
        const auto file = resources->directory / name;
        const auto module = LoadLibraryExW(
            file.c_str(), nullptr,
            LOAD_LIBRARY_SEARCH_DLL_LOAD_DIR | LOAD_LIBRARY_SEARCH_SYSTEM32);
        if (!module)
          throw std::runtime_error("Cannot load pinned TensorRT DLL");
        modules.push_back(module);
      }
      const auto version = reinterpret_cast<int32_t (*)()>(
          GetProcAddress(modules.back(), "getInferLibVersion"));
      create = reinterpret_cast<Create>(
          GetProcAddress(modules.back(), "createInferRuntime_INTERNAL"));
      if (!create || !version || version() != NV_TENSORRT_VERSION)
        throw std::runtime_error(
            "Pinned TensorRT runtime API version mismatch");
    } catch (...) {
      for (auto it = modules.rbegin(); it != modules.rend(); ++it)
        FreeLibrary(*it);
      modules.clear();
      throw;
    }
  }
  ~Runtime() {
    for (auto it = modules.rbegin(); it != modules.rend(); ++it)
      FreeLibrary(*it);
  }
};

std::shared_ptr<Runtime> GetRuntime(std::shared_ptr<TrtResources> resources) {
  static std::mutex mutex;
  // CUDA/TRT versions cannot be changed in an existing process. Retain the
  // first set and its immutable leases even between Players.
  static std::shared_ptr<Runtime> retained;
  std::lock_guard<std::mutex> lock(mutex);
  if (retained && retained->resources->directory != resources->directory)
    throw std::runtime_error("Changing TensorRT resources requires a restart");
  if (!retained) retained = std::make_shared<Runtime>(std::move(resources));
  return retained;
}

void Check(bool success, const char* message) {
  if (!success) throw std::runtime_error(message);
}

ComPtr<ID3D11Texture2D> CudaTexture(ID3D11Texture2D* source) {
  D3D11_TEXTURE2D_DESC description{};
  source->GetDesc(&description);
  Check(description.Format == DXGI_FORMAT_R16_FLOAT &&
            description.ArraySize == 1 && description.MipLevels == 1 &&
            description.SampleDesc.Count == 1,
        "CUDA texture must be planar FP16");
  // Register a private RGB intermediate, never a decoder's NV12/P010 texture
  // or a shared D3D12 resource. Copies stay on the playback device.
  description.MiscFlags = 0;
  ComPtr<ID3D11Device> device;
  source->GetDevice(&device);
  ComPtr<ID3D11Texture2D> result;
  Check(SUCCEEDED(device->CreateTexture2D(&description, nullptr, &result)),
        "Cannot create CUDA RGB intermediate");
  return result;
}
}  // namespace

struct TrtSession::State {
  CudaApi cuda;
  CUcontext context = nullptr;
  int device = -1;
  CUstream stream = nullptr;
  std::array<CUevent, 2> events{};
  CUdeviceptr input = 0;
  CUdeviceptr output = 0;
  std::array<CUgraphicsResource, 2> graphics{};
  std::shared_ptr<Runtime> library;
  Logger logger;
  std::unique_ptr<LockedAsset> engine_lease;
  std::unique_ptr<nvinfer1::IRuntime> runtime;
  std::unique_ptr<nvinfer1::ICudaEngine> engine;
  std::unique_ptr<nvinfer1::IExecutionContext> execution;
  ComPtr<ID3D11Texture2D> source;
  ComPtr<ID3D11Texture2D> destination;
  ComPtr<ID3D11Texture2D> cuda_input;
  ComPtr<ID3D11Texture2D> cuda_output;
  uint32_t width = 0;
  uint32_t height = 0;
  bool pending = false;
  bool mapped = false;
  bool completion_failed = false;
  double gpu_ms = 0;

  void Wait() {
    if (!pending) return;
    Check(!completion_failed, "CUDA completion event could not be recorded");
    const auto deadline = Clock::now() + std::chrono::seconds(30);
    for (;;) {
      const auto result = cuda.cuEventQuery(events[1]);
      if (result == CUDA_SUCCESS) break;
      if (result != CUDA_ERROR_NOT_READY)
        CudaApi::Check(result, "CUDA completion");
      if (Clock::now() >= deadline)
        throw std::runtime_error("CUDA frame timeout");
      std::this_thread::sleep_for(std::chrono::milliseconds(1));
    }
    pending = false;
    float elapsed = 0;
    CudaApi::Check(cuda.cuEventElapsedTime(&elapsed, events[0], events[1]),
                   "CUDA inference timing");
    gpu_ms = elapsed;
  }

  ~State() {
    if (!context) return;
    try {
      CudaScope scope(cuda, context);
      Wait();
      if (mapped) cuda.cuGraphicsUnmapResources(2, graphics.data(), stream);
      for (auto resource : graphics)
        if (resource) cuda.cuGraphicsUnregisterResource(resource);
      execution.reset();
      engine.reset();
      runtime.reset();
      if (input) cuda.cuMemFree(input);
      if (output) cuda.cuMemFree(output);
      for (auto event : events)
        if (event) cuda.cuEventDestroy(event);
      if (stream) cuda.cuStreamDestroy(stream);
    } catch (...) {
      // A device error makes resource retirement best effort. The caller keeps
      // a faulted State alive instead of entering this destructor on a timeout.
    }
    cuda.cuDevicePrimaryCtxRelease(device);
  }
};

TrtSession::TrtSession(std::shared_ptr<TrtResources> resources,
                       const std::filesystem::path& file,
                       const GpuCapabilities& gpu, uint32_t width,
                       uint32_t height)
    : state_(std::make_unique<State>()) {
  try {
    auto& state = *state_;
    state.width = width;
    state.height = height;
    state.device = gpu.cuda_device;
    CudaApi::Check(
        state.cuda.cuDevicePrimaryCtxRetain(&state.context, state.device),
        "Retain playback CUDA context");
    CudaScope scope(state.cuda, state.context);
    state.library = GetRuntime(std::move(resources));
    state.runtime.reset(static_cast<nvinfer1::IRuntime*>(
        state.library->create(&state.logger, NV_TENSORRT_VERSION)));
    Check(state.runtime != nullptr, "Cannot create TensorRT runtime");
    state.runtime->setEngineHostCodeAllowed(false);
    const uint64_t bytes = std::filesystem::file_size(file);
    Check(bytes > 0 && bytes <= 512 * 1024 * 1024,
          "Invalid TensorRT engine size");
    state.engine_lease =
        LockedAsset::File(file, bytes, LockedAsset::Sha256(file));
    std::ifstream input(file, std::ios::binary);
    std::vector<char> data(static_cast<size_t>(bytes));
    input.read(data.data(), static_cast<std::streamsize>(data.size()));
    Check(input.good(), "Cannot read TensorRT engine");
    state.engine.reset(
        state.runtime->deserializeCudaEngine(data.data(), data.size()));
    Check(state.engine != nullptr, state.logger.error.empty()
                                       ? "Cannot deserialize TensorRT engine"
                                       : state.logger.error.c_str());
    Check(state.engine->getNbIOTensors() == 2,
          "TensorRT model IO count mismatch");
    state.execution.reset(state.engine->createExecutionContext());
    Check(state.execution != nullptr,
          "Cannot create TensorRT execution context");
    const nvinfer1::Dims input_shape{4, {1, 3, height, width}};
    Check(state.engine->getNbOptimizationProfiles() == 1,
          "TensorRT requires exactly one fixed input profile");
    for (auto selector : {nvinfer1::OptProfileSelector::kMIN,
                          nvinfer1::OptProfileSelector::kOPT,
                          nvinfer1::OptProfileSelector::kMAX}) {
      const auto profile = state.engine->getProfileShape("input", 0, selector);
      Check(profile.nbDims == 4 && profile.d[0] == 1 && profile.d[1] == 3 &&
                profile.d[2] == height && profile.d[3] == width,
            "TensorRT input profile must match the fixed cache shape");
    }
    Check(state.execution->setInputShape("input", input_shape),
          "Cannot set the fixed TensorRT input shape");
    for (bool is_input : {true, false}) {
      const char* name = is_input ? "input" : "output";
      const auto shape = state.execution->getTensorShape(name);
      const int64_t scale = is_input ? 1 : 2;
      Check(shape.nbDims == 4 && shape.d[0] == 1 && shape.d[1] == 3 &&
                shape.d[2] == height * scale && shape.d[3] == width * scale &&
                state.engine->getTensorDataType(name) ==
                    nvinfer1::DataType::kHALF &&
                state.engine->getTensorFormat(name) ==
                    nvinfer1::TensorFormat::kLINEAR &&
                state.engine->getTensorLocation(name) ==
                    nvinfer1::TensorLocation::kDEVICE &&
                state.engine->getTensorIOMode(name) ==
                    (is_input ? nvinfer1::TensorIOMode::kINPUT
                              : nvinfer1::TensorIOMode::kOUTPUT),
            "TensorRT model must be static FP16 NCHW with 2x output");
    }
    CudaApi::Check(
        state.cuda.cuStreamCreate(&state.stream, CU_STREAM_NON_BLOCKING),
        "Create CUDA stream");
    for (auto& event : state.events)
      CudaApi::Check(state.cuda.cuEventCreate(&event, CU_EVENT_DEFAULT),
                     "CUDA event");
    const size_t tensor_bytes = size_t{width} * height * 3 * 2;
    CudaApi::Check(state.cuda.cuMemAlloc(&state.input, tensor_bytes),
                   "CUDA input");
    CudaApi::Check(state.cuda.cuMemAlloc(&state.output, tensor_bytes * 4),
                   "CUDA output");
    Check(state.execution->setTensorAddress(
              "input", reinterpret_cast<void*>(state.input)) &&
              state.execution->setTensorAddress(
                  "output", reinterpret_cast<void*>(state.output)),
          "Cannot bind TensorRT GPU tensors");
    CudaApi::Check(state.cuda.cuEventRecord(state.events[0], state.stream),
                   "Warmup start");
    state.pending = true;
    CudaApi::Check(
        state.cuda.cuMemsetD8Async(state.input, 0, tensor_bytes, state.stream),
        "Initialize warmup input");
    Check(state.execution->enqueueV3(state.stream), "TensorRT warmup failed");
    CudaApi::Check(state.cuda.cuEventRecord(state.events[1], state.stream),
                   "Warmup end");
    state.Wait();
  } catch (...) {
    // Constructor failures bypass ~TrtSession. Keep resources alive if CUDA
    // accepted work but its completion cannot be established.
    if (state_ && state_->pending) (void)state_.release();
    throw;
  }
}

TrtSession::~TrtSession() {
  if (!state_ || !state_->context) return;
  try {
    CudaScope scope(state_->cuda, state_->context);
    state_->Wait();
  } catch (...) {
    // Retain resources referenced by a hung GPU until process exit. Releasing
    // CUDA buffers, COM textures or DLLs while work is pending is unsafe.
    (void)state_.release();
  }
}

void TrtSession::Attach(ID3D11Texture2D* input, ID3D11Texture2D* output) {
  auto& state = *state_;
  Check(input && output && !state.source,
        "Invalid TensorRT texture attachment");
  CudaScope scope(state.cuda, state.context);
  state.source = input;
  state.destination = output;
  state.cuda_input = CudaTexture(input);
  state.cuda_output = CudaTexture(output);
  for (size_t i = 0; i < state.graphics.size(); ++i) {
    CudaApi::Check(
        state.cuda.cuGraphicsD3D11RegisterResource(
            &state.graphics[i],
            i == 0 ? state.cuda_input.Get() : state.cuda_output.Get(),
            CU_GRAPHICS_REGISTER_FLAGS_NONE),
        "Register CUDA D3D11 RGB texture");
  }
}

void TrtSession::Run(ID3D11DeviceContext* context) {
  auto& state = *state_;
  CudaScope scope(state.cuda, state.context);
  state.Wait();
  context->CopyResource(state.cuda_input.Get(), state.source.Get());
  context->Flush();
  CudaApi::Check(
      state.cuda.cuGraphicsMapResources(2, state.graphics.data(), state.stream),
      "Map D3D11 textures to CUDA");
  state.mapped = true;
  try {
    CudaApi::Check(state.cuda.cuEventRecord(state.events[0], state.stream),
                   "CUDA start");
    std::array<CUarray, 2> arrays{};
    for (size_t i = 0; i < arrays.size(); ++i)
      CudaApi::Check(state.cuda.cuGraphicsSubResourceGetMappedArray(
                         &arrays[i], state.graphics[i], 0, 0),
                     "Get CUDA texture array");
    CUDA_MEMCPY2D copy{};
    copy.srcMemoryType = CU_MEMORYTYPE_ARRAY;
    copy.srcArray = arrays[0];
    copy.dstMemoryType = CU_MEMORYTYPE_DEVICE;
    copy.dstDevice = state.input;
    copy.dstPitch = copy.WidthInBytes = size_t{state.width} * 2;
    copy.Height = size_t{state.height} * 3;
    CudaApi::Check(state.cuda.cuMemcpy2DAsync(&copy, state.stream),
                   "Pack FP16 NCHW");
    Check(state.execution->enqueueV3(state.stream),
          "TensorRT inference failed");
    copy = {};
    copy.srcMemoryType = CU_MEMORYTYPE_DEVICE;
    copy.srcDevice = state.output;
    copy.srcPitch = copy.WidthInBytes = size_t{state.width} * 4;
    copy.dstMemoryType = CU_MEMORYTYPE_ARRAY;
    copy.dstArray = arrays[1];
    copy.Height = size_t{state.height} * 6;
    CudaApi::Check(state.cuda.cuMemcpy2DAsync(&copy, state.stream),
                   "Unpack FP16 RGB");
    CudaApi::Check(state.cuda.cuEventRecord(state.events[1], state.stream),
                   "CUDA end");
    state.pending = true;
    CudaApi::Check(state.cuda.cuGraphicsUnmapResources(2, state.graphics.data(),
                                                       state.stream),
                   "Release textures to D3D11");
    state.mapped = false;
  } catch (...) {
    state.completion_failed =
        state.cuda.cuEventRecord(state.events[1], state.stream) != CUDA_SUCCESS;
    state.pending = true;
    if (state.cuda.cuGraphicsUnmapResources(2, state.graphics.data(),
                                            state.stream) == CUDA_SUCCESS)
      state.mapped = false;
    throw;
  }
  // CUDA unmap orders subsequent graphics commands after all CUDA writes.
  context->CopyResource(state.destination.Get(), state.cuda_output.Get());
}
double TrtSession::last_gpu_ms() const { return state_->gpu_ms; }
}  // namespace bangumi::inference
