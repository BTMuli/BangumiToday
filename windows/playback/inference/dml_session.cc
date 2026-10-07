// Copyright (c) BangumiToday contributors. Licensed under the project MIT
// license.
#include "dml_session.h"

#include <DirectML.h>
#include <Windows.h>
#include <dml_provider_factory.h>
#include <dxgi1_4.h>
#include <onnxruntime_c_api.h>

#include <array>
#include <atomic>
#include <chrono>
#include <limits>
#include <mutex>
#include <stdexcept>
#include <string>
#include <thread>

#include "trusted_assets.h"

namespace bangumi::inference {
namespace {
using Microsoft::WRL::ComPtr;
using CreateDmlDevice = HRESULT(WINAPI*)(ID3D12Device*, DML_CREATE_DEVICE_FLAGS,
                                         REFIID, void**);

void Check(HRESULT result, const char* operation) {
  if (FAILED(result)) {
    throw std::runtime_error(std::string(operation) + ": HRESULT=" +
                             std::to_string(static_cast<uint32_t>(result)));
  }
}

class Module final {
 public:
  explicit Module(const std::filesystem::path& path)
      : asset_(LockedAsset::Runtime(path)) {
    handle_ = LoadLibraryExW(
        path.c_str(), nullptr,
        LOAD_LIBRARY_SEARCH_DLL_LOAD_DIR | LOAD_LIBRARY_SEARCH_SYSTEM32);
    if (!handle_)
      throw std::runtime_error("Cannot load inference DLL: " +
                               std::to_string(GetLastError()));
    std::array<wchar_t, 32768> actual{};
    const auto count = GetModuleFileNameW(handle_, actual.data(),
                                          static_cast<DWORD>(actual.size()));
    std::error_code path_error;
    if (!count || count >= actual.size() ||
        !std::filesystem::equivalent(path, actual.data(), path_error)) {
      FreeLibrary(handle_);
      handle_ = nullptr;
      throw std::runtime_error(
          "Inference DLL was resolved from a different path");
    }
  }
  ~Module() {
    if (handle_) FreeLibrary(handle_);
  }
  template <class T>
  T Symbol(const char* name) const {
    auto symbol = GetProcAddress(handle_, name);
    if (!symbol)
      throw std::runtime_error(std::string("Missing DLL export: ") + name);
    return reinterpret_cast<T>(symbol);
  }

 private:
  HMODULE handle_ = nullptr;
  std::unique_ptr<LockedAsset> asset_;
};

struct Runtime final {
  explicit Runtime(const std::filesystem::path& directory)
      : directml(directory / L"DirectML.dll"),
        onnx(directory / L"onnxruntime.dll") {
    auto base =
        onnx.Symbol<const OrtApiBase*(ORT_API_CALL*)()>("OrtGetApiBase")();
    api = base->GetApi(ORT_API_VERSION);
    if (!api) throw std::runtime_error("ONNX Runtime API version mismatch");
    const void* provider = nullptr;
    CheckOrt(api->GetExecutionProviderApi("DML", ORT_API_VERSION, &provider));
    dml = static_cast<const OrtDmlApi*>(provider);
    create_device = directml.Symbol<CreateDmlDevice>("DMLCreateDevice");
  }
  void CheckOrt(OrtStatus* status) const {
    if (!status) return;
    std::string message = api->GetErrorMessage(status);
    api->ReleaseStatus(status);
    throw std::runtime_error(message);
  }
  Module directml;
  Module onnx;
  const OrtApi* api = nullptr;
  const OrtDmlApi* dml = nullptr;
  CreateDmlDevice create_device = nullptr;
};

std::shared_ptr<Runtime> GetRuntime(const std::filesystem::path& directory) {
  // Different ORT versions cannot coexist under the same DLL basename. Retain
  // the first verified runtime until process exit, including between Players.
  static std::mutex mutex;
  static std::filesystem::path loaded_directory;
  static std::shared_ptr<Runtime> loaded;
  std::lock_guard<std::mutex> lock(mutex);
  const auto normalized = std::filesystem::canonical(directory);
  if (loaded && loaded_directory != normalized) {
    throw std::runtime_error(
        "Changing inference runtime requires an app restart");
  }
  if (!loaded) {
    loaded = std::make_shared<Runtime>(normalized);
    loaded_directory = normalized;
  }
  return loaded;
}

ComPtr<ID3D12Resource> TensorBuffer(ID3D12Device* device, uint64_t bytes) {
  D3D12_HEAP_PROPERTIES heap{};
  heap.Type = D3D12_HEAP_TYPE_DEFAULT;
  D3D12_RESOURCE_DESC description{};
  description.Dimension = D3D12_RESOURCE_DIMENSION_BUFFER;
  description.Width = (bytes + 3) & ~uint64_t{3};
  description.Height = 1;
  description.DepthOrArraySize = 1;
  description.MipLevels = 1;
  description.SampleDesc.Count = 1;
  description.Layout = D3D12_TEXTURE_LAYOUT_ROW_MAJOR;
  description.Flags = D3D12_RESOURCE_FLAG_ALLOW_UNORDERED_ACCESS;
  ComPtr<ID3D12Resource> resource;
  Check(device->CreateCommittedResource(
            &heap, D3D12_HEAP_FLAG_NONE, &description,
            D3D12_RESOURCE_STATE_COMMON, nullptr, IID_PPV_ARGS(&resource)),
        "Create tensor buffer");
  return resource;
}
}  // namespace

struct DmlSession::State final {
  explicit State(std::shared_ptr<Runtime> value) : runtime(std::move(value)) {}
  ~State() {
    auto api = runtime->api;
    if (binding) api->ReleaseIoBinding(binding);
    if (input_value) api->ReleaseValue(input_value);
    if (output_value) api->ReleaseValue(output_value);
    if (input_allocation) {
      if (auto status = runtime->dml->FreeGPUAllocation(input_allocation)) {
        api->ReleaseStatus(status);
      }
    }
    if (output_allocation) {
      if (auto status = runtime->dml->FreeGPUAllocation(output_allocation)) {
        api->ReleaseStatus(status);
      }
    }
    if (session) api->ReleaseSession(session);
    if (options) api->ReleaseSessionOptions(options);
    if (memory_info) api->ReleaseMemoryInfo(memory_info);
    if (environment) api->ReleaseEnv(environment);
  }
  InteropContext* interop = nullptr;
  std::shared_ptr<Runtime> runtime;
  ComPtr<IDMLDevice> dml_device;
  ComPtr<ID3D12Resource> input, output;
  // Kept so an abnormal teardown can poll completion through the fence alone,
  // without dereferencing a context that may already be gone.
  ComPtr<ID3D12Fence> fence;
  std::unique_ptr<LockedAsset> model;
  OrtEnv* environment = nullptr;
  OrtSessionOptions* options = nullptr;
  OrtSession* session = nullptr;
  OrtMemoryInfo* memory_info = nullptr;
  OrtIoBinding* binding = nullptr;
  OrtValue* input_value = nullptr;
  OrtValue* output_value = nullptr;
  void* input_allocation = nullptr;
  void* output_allocation = nullptr;
  uint32_t width = 0, height = 0;
  uint64_t input_size = 0, output_size = 0;
  bool profiling_requested = false;
  std::atomic<uint64_t> last_ticket{0};
  bool failed = false;
  LUID luid{};
  std::mutex mutex;
};

DmlSession::DmlSession(InteropContext& interop,
                       const std::filesystem::path& runtime_directory,
                       const std::filesystem::path& model, uint32_t width,
                       uint32_t height, const Options& options) {
  if (!model.is_absolute() || !width || !height ||
      uint64_t{width} * 2 * (height * 2) * 3 * 2 > 3840ull * 2160 * 3 * 2) {
    throw std::invalid_argument("Invalid JaNai model path or input budget");
  }
  state_ = std::make_unique<State>(GetRuntime(runtime_directory));
  auto& state = *state_;
  state.interop = &interop;
  state.fence = interop.fence();
  state.width = width;
  state.height = height;
  state.model = LockedAsset::Model(model);
  auto api = state.runtime->api;
  auto check = [&](OrtStatus* status) { state.runtime->CheckOrt(status); };
  state.luid = interop.adapter_luid();

  Check(state.runtime->create_device(interop.device(),
                                     DML_CREATE_DEVICE_FLAG_NONE,
                                     IID_PPV_ARGS(&state.dml_device)),
        "DirectML device");
  check(api->CreateEnv(
      static_cast<OrtLoggingLevel>(options.log_severity), "BangumiToday.JaNai",
      &state.environment));
  check(api->CreateSessionOptions(&state.options));
  check(api->SetSessionExecutionMode(state.options, ORT_SEQUENTIAL));
  check(api->DisableMemPattern(state.options));
  check(api->SetSessionGraphOptimizationLevel(state.options, ORT_ENABLE_ALL));
  check(api->AddSessionConfigEntry(state.options,
                                   "session.disable_cpu_ep_fallback", "1"));
  check(api->AddFreeDimensionOverrideByName(state.options, "height", height));
  check(api->AddFreeDimensionOverrideByName(state.options, "width", width));
  if (!options.placement_profile.empty()) {
    if (!options.placement_profile.is_absolute())
      throw std::invalid_argument("Placement profile path must be absolute");
    check(api->EnableProfiling(state.options,
                               options.placement_profile.c_str()));
    state.profiling_requested = true;
  }
  check(state.runtime->dml->SessionOptionsAppendExecutionProvider_DML1(
      state.options, state.dml_device.Get(), interop.queue()));
  check(api->CreateSession(state.environment, model.c_str(), state.options,
                           &state.session));

  // Validate the loaded graph, not its filename. Dynamic output annotations
  // in these models reuse input dimension names; binding the exact 2x output
  // below makes an incorrect actual output shape a Run failure.
  for (bool input : {true, false}) {
    size_t count = 0;
    check(input ? api->SessionGetInputCount(state.session, &count)
                : api->SessionGetOutputCount(state.session, &count));
    if (count != 1)
      throw std::runtime_error("JaNai graph must have one input and output");
    OrtTypeInfo* type = nullptr;
    check(input ? api->SessionGetInputTypeInfo(state.session, 0, &type)
                : api->SessionGetOutputTypeInfo(state.session, 0, &type));
    struct TypeScope {
      const OrtApi* api;
      OrtTypeInfo* value;
      ~TypeScope() { api->ReleaseTypeInfo(value); }
    } scope{api, type};
    const OrtTensorTypeAndShapeInfo* tensor = nullptr;
    check(api->CastTypeInfoToTensorInfo(type, &tensor));
    if (!tensor) throw std::runtime_error("JaNai graph IO is not a tensor");
    ONNXTensorElementDataType element{};
    size_t rank = 0;
    check(api->GetTensorElementType(tensor, &element));
    check(api->GetDimensionsCount(tensor, &rank));
    if (element != ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT16 || rank != 4) {
      throw std::runtime_error("JaNai graph IO must be FP16 NCHW");
    }
    std::array<int64_t, 4> shape{};
    check(api->GetDimensions(tensor, shape.data(), shape.size()));
    if (shape[1] != 3 || (input && shape[0] != 1)) {
      throw std::runtime_error("JaNai graph IO batch/channel mismatch");
    }
    OrtAllocator* allocator = nullptr;
    check(api->GetAllocatorWithDefaultOptions(&allocator));
    char* name = nullptr;
    check(input
              ? api->SessionGetInputName(state.session, 0, allocator, &name)
              : api->SessionGetOutputName(state.session, 0, allocator, &name));
    const bool matches =
        name && std::string(name) == (input ? "input" : "output");
    allocator->Free(allocator, name);
    if (!matches) throw std::runtime_error("JaNai graph IO name mismatch");
  }
  state.input_size = uint64_t{width} * height * 3 * 2;
  state.output_size = state.input_size * 4;
  state.input = TensorBuffer(interop.device(), state.input_size);
  state.output = TensorBuffer(interop.device(), state.output_size);
  check(state.runtime->dml->CreateGPUAllocationFromD3DResource(
      state.input.Get(), &state.input_allocation));
  check(state.runtime->dml->CreateGPUAllocationFromD3DResource(
      state.output.Get(), &state.output_allocation));
  check(api->CreateMemoryInfo("DML", OrtDeviceAllocator, 0, OrtMemTypeDefault,
                              &state.memory_info));
  const int64_t input_shape[] = {1, 3, height, width};
  const int64_t output_shape[] = {1, 3, height * 2, width * 2};
  check(api->CreateTensorWithDataAsOrtValue(
      state.memory_info, state.input_allocation, state.input_size, input_shape,
      4, ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT16, &state.input_value));
  check(api->CreateTensorWithDataAsOrtValue(
      state.memory_info, state.output_allocation, state.output_size,
      output_shape, 4, ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT16,
      &state.output_value));
  check(api->CreateIoBinding(state.session, &state.binding));
  check(api->BindInput(state.binding, "input", state.input_value));
  check(api->BindOutput(state.binding, "output", state.output_value));
}

DmlSession::~DmlSession() {
  if (!state_ || !state_->last_ticket) return;
  try {
    Wait(state_->last_ticket);
  } catch (...) {
    // A hung, live device still owns the in-flight buffers. Keep them until
    // completion/device removal on a worker instead of recycling them after a
    // timeout. A removed device's UINT64_MAX fence also releases this lease.
    auto pending = state_.release();
    try {
      std::thread([pending]() {
        // Poll the fence itself: the interop context may already be gone, and
        // a device removal reports UINT64_MAX instead of a value.
        while (pending->fence->GetCompletedValue() < pending->last_ticket) {
          const uint64_t completed = pending->fence->GetCompletedValue();
          if (completed == std::numeric_limits<uint64_t>::max()) break;
          if (completed >= pending->last_ticket) break;
          std::this_thread::sleep_for(std::chrono::milliseconds(100));
        }
        delete pending;
      }).detach();
    } catch (...) {
      // If even a cleanup worker cannot start, retain this lease until process
      // exit. Freeing a buffer still in GPU use is unsafe; recovery must stop
      // this Player from applying another inference session after this fault.
    }
  }
}

ID3D12Resource* DmlSession::input() const { return state_->input.Get(); }
ID3D12Resource* DmlSession::output() const { return state_->output.Get(); }
uint64_t DmlSession::input_bytes() const { return state_->input_size; }
uint64_t DmlSession::output_bytes() const { return state_->output_size; }
uint32_t DmlSession::width() const { return state_->width; }
uint32_t DmlSession::height() const { return state_->height; }
LUID DmlSession::adapter_luid() const { return state_->luid; }

uint64_t DmlSession::Run() {
  std::lock_guard<std::mutex> lock(state_->mutex);
  if (state_->failed)
    throw std::runtime_error("JaNai session requires recovery");
  // Runs may overlap. The shared queue executes them in submission order, so a
  // later input copy can never overtake an earlier read of the same tensor,
  // and DirectML sessions are built for a queue depth above one. The caller
  // must order its own writes to the tensor on the GPU (FramePipeline does
  // this with the shared fence) rather than relying on a CPU wait here.
  auto status = state_->runtime->api->RunWithBinding(
      state_->session, nullptr, state_->binding);
  uint64_t ticket = 0;
  try {
    // Publish the run on the shared fence even when Run failed, because a
    // failed run may still have submitted GPU work over these tensors.
    ticket = state_->interop->SignalQueue();
  } catch (...) {
    state_->failed = true;
    state_->runtime->CheckOrt(status);
    throw;
  }
  state_->last_ticket = ticket;
  if (status) {
    state_->failed = true;
    state_->runtime->CheckOrt(status);
  }
  return ticket;
}

bool DmlSession::Complete(uint64_t ticket) const {
  if (ticket > state_->last_ticket)
    throw std::invalid_argument("Unknown inference ticket");
  return state_->interop->Complete(ticket);
}

void DmlSession::Wait(uint64_t ticket, uint32_t timeout_ms) {
  std::lock_guard<std::mutex> lock(state_->mutex);
  if (Complete(ticket)) return;
  state_->interop->Wait(ticket, timeout_ms);
  if (!Complete(ticket))
    throw std::runtime_error("JaNai inference did not complete");
}

std::filesystem::path DmlSession::EndPlacementProfiling() {
  std::lock_guard<std::mutex> lock(state_->mutex);
  if (!state_->profiling_requested) return {};
  state_->profiling_requested = false;
  auto api = state_->runtime->api;
  OrtAllocator* allocator = nullptr;
  state_->runtime->CheckOrt(api->GetAllocatorWithDefaultOptions(&allocator));
  char* path = nullptr;
  state_->runtime->CheckOrt(
      api->SessionEndProfiling(state_->session, allocator, &path));
  std::filesystem::path result;
  if (path) {
    result = std::filesystem::path(path);
    allocator->Free(allocator, path);
  }
  return result;
}
}  // namespace bangumi::inference
