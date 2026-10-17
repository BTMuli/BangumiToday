// Copyright (c) BangumiToday contributors. Licensed under the project MIT.
#include "trt_session.h"

#include <NvInferRuntime.h>
#include <wrl/client.h>

#include <algorithm>
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

void ValidateCudaTexture(ID3D11Texture2D* source, uint32_t width,
                         uint32_t height) {
  D3D11_TEXTURE2D_DESC description{};
  source->GetDesc(&description);
  Check(description.Format == DXGI_FORMAT_R16_FLOAT &&
            description.ArraySize == 1 && description.MipLevels == 1 &&
            description.SampleDesc.Count == 1 &&
            description.Width == width && description.Height == height &&
            description.MiscFlags == 0,
        "CUDA texture must be private planar FP16 of the fixed tensor shape");
}

void ValidateOutputBuffer(ID3D11Buffer* destination, uint32_t width,
                          uint32_t height) {
  D3D11_BUFFER_DESC description{};
  destination->GetDesc(&description);
  const uint64_t bytes = uint64_t{width} * 2 * height * 6 * 2;
  Check(description.ByteWidth == bytes &&
            description.Usage == D3D11_USAGE_DEFAULT &&
            (description.BindFlags & D3D11_BIND_SHADER_RESOURCE) != 0 &&
            description.CPUAccessFlags == 0,
        "TensorRT output must be a mapped FP16 plane buffer");
}
}  // namespace

struct TrtSession::State {
  CudaApi cuda;
  CUcontext context = nullptr;
  int device = -1;
  CUstream stream = nullptr;
  std::array<CUevent, 4> events{};
  CUevent completion = nullptr;
  CUgraphExec graph = nullptr;
  CUdeviceptr input = 0;
  // Warmup tensor used until the session is attached to the converter.
  CUdeviceptr warmup_output = 0;
  // Device pointer of the converter's mapped output buffer. TensorRT writes
  // here directly; the converter never copies the planes back into a texture.
  CUdeviceptr output_pointer = 0;
  std::array<CUgraphicsResource, 2> graphics{};
  std::shared_ptr<Runtime> library;
  Logger logger;
  std::unique_ptr<LockedAsset> engine_lease;
  std::unique_ptr<nvinfer1::IRuntime> runtime;
  std::unique_ptr<nvinfer1::ICudaEngine> engine;
  std::unique_ptr<nvinfer1::IExecutionContext> execution;
  ComPtr<ID3D11Texture2D> source;
  ComPtr<ID3D11Buffer> destination;
  uint32_t width = 0;
  uint32_t height = 0;
  bool pending = false;
  bool mapped = false;
  bool completion_failed = false;
  bool timing_pending = false;
  GpuTiming gpu_timing;
  SubmissionTiming submission_timing;

  bool CollectTiming() {
    if (!timing_pending) return false;
    const auto result = cuda.cuEventQuery(events.back());
    if (result == CUDA_ERROR_NOT_READY) return false;
    CudaApi::Check(result, "CUDA timing completion");
    const auto elapsed = [&](size_t begin, size_t end) {
      float milliseconds = 0;
      CudaApi::Check(cuda.cuEventElapsedTime(&milliseconds, events[begin],
                                             events[end]),
                     "CUDA frame stage timing");
      return static_cast<double>(milliseconds);
    };
    gpu_timing.input_copy_ms = elapsed(0, 1);
    gpu_timing.inference_ms = elapsed(1, 2);
    gpu_timing.output_copy_ms = elapsed(2, 3);
    gpu_timing.total_ms = elapsed(0, 3);
    timing_pending = false;
    return true;
  }

  void CaptureGraph() {
    // Shape updates were flushed by warmup. Only capture inference: graphics
    // map/unmap happen per frame, while the input tensor address and the mapped
    // output buffer address stay fixed for the session's entire lifetime.
    if (cuda.cuStreamBeginCapture(stream, CU_STREAM_CAPTURE_MODE_THREAD_LOCAL) !=
        CUDA_SUCCESS)
      return;
    CUgraph captured = nullptr;
    const bool enqueued = execution->enqueueV3(stream);
    const auto ended = cuda.cuStreamEndCapture(stream, &captured);
    if (enqueued && ended == CUDA_SUCCESS && captured) {
      CUgraphExec instance = nullptr;
      if (cuda.cuGraphInstantiateWithFlags(&instance, captured, 0) == CUDA_SUCCESS)
        graph = instance;
      else if (instance)
        cuda.cuGraphExecDestroy(instance);
    }
    if (captured) cuda.cuGraphDestroy(captured);
    // Unsupported capture keeps the same warmed TensorRT context usable for
    // ordinary enqueueV3 inference; it never changes backend or model.
  }

  void Enqueue() {
    if (graph)
      CudaApi::Check(cuda.cuGraphLaunch(graph, stream), "TensorRT graph launch");
    else
      Check(execution->enqueueV3(stream), "TensorRT inference failed");
  }

  void Wait() {
    if (!pending) return;
    Check(!completion_failed, "CUDA completion event could not be recorded");
    const auto deadline = Clock::now() + std::chrono::seconds(30);
    for (;;) {
      const auto result = cuda.cuEventQuery(completion);
      if (result == CUDA_SUCCESS) break;
      if (result != CUDA_ERROR_NOT_READY)
        CudaApi::Check(result, "CUDA completion");
      if (Clock::now() >= deadline)
        throw std::runtime_error("CUDA frame timeout");
      std::this_thread::sleep_for(std::chrono::milliseconds(1));
    }
    pending = false;
    CollectTiming();
  }

  ~State() {
    if (!context) return;
    try {
      CudaScope scope(cuda, context);
      Wait();
      if (mapped) cuda.cuGraphicsUnmapResources(2, graphics.data(), stream);
      for (auto resource : graphics)
        if (resource) cuda.cuGraphicsUnregisterResource(resource);
      if (graph) cuda.cuGraphExecDestroy(graph);
      execution.reset();
      engine.reset();
      runtime.reset();
      if (input) cuda.cuMemFree(input);
      if (warmup_output) cuda.cuMemFree(warmup_output);
      for (auto event : events)
        if (event) cuda.cuEventDestroy(event);
      if (completion) cuda.cuEventDestroy(completion);
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
                       uint32_t height,
                       const std::function<void()>& checkpoint,
                       const std::function<void(const char*)>& progress)
    : state_(std::make_unique<State>()) {
  try {
    const auto step = [&](const char* reason) {
      if (checkpoint) checkpoint();
      if (progress) progress(reason);
    };
    const AssetReadProgress reading = [&](uint64_t) {
      if (checkpoint) checkpoint();
    };
    step("正在初始化 CUDA 上下文");
    auto& state = *state_;
    state.width = width;
    state.height = height;
    state.device = gpu.cuda_device;
    CudaApi::Check(
        state.cuda.cuDevicePrimaryCtxRetain(&state.context, state.device),
        "Retain playback CUDA context");
    CudaScope scope(state.cuda, state.context);
    step("正在加载 TensorRT 运行库");
    state.library = GetRuntime(std::move(resources));
    step("正在创建 TensorRT 运行时");
    state.runtime.reset(static_cast<nvinfer1::IRuntime*>(
        state.library->create(&state.logger, NV_TENSORRT_VERSION)));
    Check(state.runtime != nullptr, "Cannot create TensorRT runtime");
    state.runtime->setEngineHostCodeAllowed(false);
    const uint64_t bytes = std::filesystem::file_size(file);
    Check(bytes > 0 && bytes <= 512 * 1024 * 1024,
          "Invalid TensorRT engine size");
    step("正在校验并读取引擎文件");
    state.engine_lease =
        LockedAsset::File(file, bytes, LockedAsset::Sha256(file, reading),
                          reading);
    std::ifstream input(file, std::ios::binary);
    std::vector<char> data(static_cast<size_t>(bytes));
    for (size_t offset = 0; offset < data.size();) {
      if (checkpoint) checkpoint();
      const auto count = std::min(size_t{1048576}, data.size() - offset);
      input.read(data.data() + offset, static_cast<std::streamsize>(count));
      Check(input.good(), "Cannot read TensorRT engine");
      offset += count;
    }
    Check(input.good(), "Cannot read TensorRT engine");
    step("正在反序列化 TensorRT 引擎");
    state.engine.reset(
        state.runtime->deserializeCudaEngine(data.data(), data.size()));
    Check(state.engine != nullptr, state.logger.error.empty()
                                       ? "Cannot deserialize TensorRT engine"
                                       : state.logger.error.c_str());
    Check(state.engine->getNbIOTensors() == 2,
          "TensorRT model IO count mismatch");
    step("正在创建执行上下文并校验张量");
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
    step("正在分配 GPU 张量和预热资源");
    CudaApi::Check(
        state.cuda.cuStreamCreate(&state.stream, CU_STREAM_NON_BLOCKING),
        "Create CUDA stream");
    for (auto& event : state.events)
      CudaApi::Check(state.cuda.cuEventCreate(&event, CU_EVENT_DEFAULT),
                     "CUDA event");
    CudaApi::Check(state.cuda.cuEventCreate(&state.completion,
                                           CU_EVENT_DISABLE_TIMING),
                   "CUDA completion event");
    const size_t tensor_bytes = size_t{width} * height * 3 * 2;
    CudaApi::Check(state.cuda.cuMemAlloc(&state.input, tensor_bytes),
                   "CUDA input");
    // Validation happens before the converter exists, so the first inference
    // uses a scratch output. Attach rebinds the tensor to the converter's
    // mapped buffer and captures the graph against that address.
    CudaApi::Check(state.cuda.cuMemAlloc(&state.warmup_output, tensor_bytes * 4),
                   "CUDA warmup output");
    Check(state.execution->setTensorAddress(
              "input", reinterpret_cast<void*>(state.input)) &&
              state.execution->setTensorAddress(
                  "output", reinterpret_cast<void*>(state.warmup_output)),
          "Cannot bind TensorRT GPU tensors");
    step("正在执行首次 GPU 预热推理");
    state.pending = true;
    CudaApi::Check(
        state.cuda.cuMemsetD8Async(state.input, 0, tensor_bytes, state.stream),
        "Initialize warmup input");
    Check(state.execution->enqueueV3(state.stream), "TensorRT warmup failed");
    CudaApi::Check(state.cuda.cuEventRecord(state.completion, state.stream),
                   "Warmup completion");
    state.Wait();
    step("引擎张量校验和 GPU 预热通过");
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

void TrtSession::Attach(ID3D11Texture2D* input, ID3D11Buffer* output) {
  auto& state = *state_;
  Check(input && output && !state.source, "Invalid TensorRT frame attachment");
  ValidateCudaTexture(input, state.width, state.height * 3);
  ValidateOutputBuffer(output, state.width, state.height);
  ComPtr<ID3D11Device> input_device;
  ComPtr<ID3D11Device> output_device;
  input->GetDevice(&input_device);
  output->GetDevice(&output_device);
  Check(input_device.Get() == output_device.Get(),
        "TensorRT resources must use the same playback device");
  CudaScope scope(state.cuda, state.context);
  state.source = input;
  state.destination = output;
  // The converter owns a private input texture and an output buffer on this
  // playback device. CUDA maps them directly, so no D3D11 copy is needed
  // before packing the input or after the model writes the output.
  for (size_t i = 0; i < state.graphics.size(); ++i) {
    ID3D11Resource* resource =
        i == 0 ? static_cast<ID3D11Resource*>(state.source.Get())
               : static_cast<ID3D11Resource*>(state.destination.Get());
    CudaApi::Check(state.cuda.cuGraphicsD3D11RegisterResource(
                       &state.graphics[i], resource,
                       CU_GRAPHICS_REGISTER_FLAGS_NONE),
                   "Register CUDA D3D11 frame resource");
  }
  // Bind the model output while the buffer is mapped. A registered resource's
  // mapping is stable; Run still verifies it and drops the captured graph if a
  // driver ever returns a different pointer.
  CudaApi::Check(
      state.cuda.cuGraphicsMapResources(2, state.graphics.data(), state.stream),
      "Map TensorRT frame resources");
  state.mapped = true;
  try {
    size_t bytes = 0;
    CudaApi::Check(state.cuda.cuGraphicsResourceGetMappedPointer(
                       &state.output_pointer, &bytes, state.graphics[1]),
                   "Map the TensorRT output buffer");
    Check(bytes >= size_t{state.width} * 2 * state.height * 6 * 2,
          "TensorRT output mapping is too small");
    Check(state.execution->setTensorAddress(
              "output", reinterpret_cast<void*>(state.output_pointer)),
          "Cannot bind the TensorRT output buffer");
    state.pending = true;
    CudaApi::Check(
        state.cuda.cuMemsetD8Async(state.input, 0,
                                   size_t{state.width} * state.height * 3 * 2,
                                   state.stream),
        "Initialize warmup input");
    Check(state.execution->enqueueV3(state.stream), "TensorRT warmup failed");
    CudaApi::Check(state.cuda.cuEventRecord(state.completion, state.stream),
                   "Warmup completion");
    state.Wait();
    state.CaptureGraph();
    // Warm the captured launch too, outside the graphics-context lock.
    if (state.graph) {
      state.pending = true;
      state.Enqueue();
      CudaApi::Check(state.cuda.cuEventRecord(state.completion, state.stream),
                     "Graph warmup completion");
      state.Wait();
    }
    CudaApi::Check(state.cuda.cuGraphicsUnmapResources(
                       2, state.graphics.data(), state.stream),
                   "Release TensorRT frame resources");
    state.mapped = false;
  } catch (...) {
    if (state.mapped &&
        state.cuda.cuGraphicsUnmapResources(2, state.graphics.data(),
                                            state.stream) == CUDA_SUCCESS)
      state.mapped = false;
    throw;
  }
  // The scratch output only carried the pre-attachment validation inference.
  if (state.warmup_output) {
    state.cuda.cuMemFree(state.warmup_output);
    state.warmup_output = 0;
  }
}

void TrtSession::Run(ID3D11DeviceContext* context, bool measure) {
  auto& state = *state_;
  Check(context && state.source && state.destination,
        "Missing TensorRT frame resources or playback context");
  CudaScope scope(state.cuda, state.context);
  Check(!state.completion_failed, "CUDA completion event could not be recorded");
  Check(!measure || !state.timing_pending,
        "The previous CUDA measurement has not been consumed");
  // The CUDA stream orders tensor reuse; graphics map/unmap orders the D3D11
  // conversion shaders. No CPU wait is needed before submitting another frame.
  context->Flush();
  const auto map_started = Clock::now();
  CudaApi::Check(
      state.cuda.cuGraphicsMapResources(2, state.graphics.data(), state.stream),
      "Map D3D11 textures to CUDA");
  state.submission_timing.map_ms =
      std::chrono::duration<double, std::milli>(Clock::now() - map_started)
          .count();
  state.mapped = true;
  state.pending = true;
  try {
    size_t mapped_bytes = 0;
    CUdeviceptr mapped_output = 0;
    CudaApi::Check(state.cuda.cuGraphicsResourceGetMappedPointer(
                       &mapped_output, &mapped_bytes, state.graphics[1]),
                   "Map the TensorRT output buffer");
    if (mapped_output != state.output_pointer) {
      state.output_pointer = mapped_output;
      Check(state.execution->setTensorAddress(
                "output", reinterpret_cast<void*>(mapped_output)),
            "Cannot bind the TensorRT output buffer");
      // The captured graph still writes to the previous mapping.
      if (state.graph) {
        state.cuda.cuGraphExecDestroy(state.graph);
        state.graph = nullptr;
      }
    }
    if (measure)
      CudaApi::Check(state.cuda.cuEventRecord(state.events[0], state.stream),
                     "CUDA start");
    CUarray array = nullptr;
    CudaApi::Check(state.cuda.cuGraphicsSubResourceGetMappedArray(
                       &array, state.graphics[0], 0, 0),
                   "Get CUDA texture array");
    CUDA_MEMCPY2D copy{};
    copy.srcMemoryType = CU_MEMORYTYPE_ARRAY;
    copy.srcArray = array;
    copy.dstMemoryType = CU_MEMORYTYPE_DEVICE;
    copy.dstDevice = state.input;
    copy.dstPitch = copy.WidthInBytes = size_t{state.width} * 2;
    copy.Height = size_t{state.height} * 3;
    CudaApi::Check(state.cuda.cuMemcpy2DAsync(&copy, state.stream),
                   "Pack FP16 NCHW");
    if (measure)
      CudaApi::Check(state.cuda.cuEventRecord(state.events[1], state.stream),
                     "CUDA input ready");
    // The model output tensor already points at the mapped buffer: TensorRT
    // writes the unpacked planes there, with no device-to-texture copy.
    state.Enqueue();
    if (measure) {
      CudaApi::Check(state.cuda.cuEventRecord(state.events[2], state.stream),
                     "CUDA inference ready");
      CudaApi::Check(state.cuda.cuEventRecord(state.events[3], state.stream),
                     "CUDA end");
      state.timing_pending = true;
    }
    const auto unmap_started = Clock::now();
    CudaApi::Check(state.cuda.cuGraphicsUnmapResources(2, state.graphics.data(),
                                                       state.stream),
                   "Release frame resources to D3D11");
    state.submission_timing.unmap_ms =
        std::chrono::duration<double, std::milli>(Clock::now() - unmap_started)
            .count();
    state.mapped = false;
    CudaApi::Check(state.cuda.cuEventRecord(state.completion, state.stream),
                   "CUDA frame completion");
  } catch (...) {
    if (state.mapped &&
        state.cuda.cuGraphicsUnmapResources(2, state.graphics.data(),
                                            state.stream) == CUDA_SUCCESS)
      state.mapped = false;
    state.completion_failed =
        state.cuda.cuEventRecord(state.completion, state.stream) != CUDA_SUCCESS;
    throw;
  }
  // CUDA unmap orders the converter's following D3D11 reads after CUDA writes.
}
bool TrtSession::ReadGpuTiming(GpuTiming* timing) {
  if (!timing) throw std::invalid_argument("Missing CUDA timing destination");
  CudaScope scope(state_->cuda, state_->context);
  if (!state_->CollectTiming()) return false;
  *timing = state_->gpu_timing;
  return true;
}
TrtSession::SubmissionTiming TrtSession::last_submission_timing() const {
  return state_->submission_timing;
}
bool TrtSession::uses_cuda_graph() const { return state_->graph != nullptr; }
}  // namespace bangumi::inference
