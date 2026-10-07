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
    if (completion) CloseHandle(completion);
  }
  std::shared_ptr<Runtime> runtime;
  ComPtr<ID3D12Device> device;
  ComPtr<ID3D12CommandQueue> queue;
  ComPtr<IDMLDevice> dml_device;
  ComPtr<ID3D12Fence> fence;
  ComPtr<ID3D12Resource> input, output;
  HANDLE completion = nullptr;
  OrtEnv* environment = nullptr;
  std::unique_ptr<LockedAsset> model;
  OrtSessionOptions* options = nullptr;
  OrtSession* session = nullptr;
  OrtMemoryInfo* memory_info = nullptr;
  OrtIoBinding* binding = nullptr;
  OrtValue* input_value = nullptr;
  OrtValue* output_value = nullptr;
  void* input_allocation = nullptr;
  void* output_allocation = nullptr;
  uint64_t input_size = 0, output_size = 0;
  std::atomic<uint64_t> last_ticket{0};
  bool failed = false;
  LUID luid{};
  std::mutex mutex;
};

DmlSession::DmlSession(const std::filesystem::path& runtime_directory,
                       const std::filesystem::path& model,
                       ID3D11Device* playback_device, uint32_t width,
                       uint32_t height) {
  if (!playback_device || !model.is_absolute() || !width || !height ||
      uint64_t{width} * height * 4 > 3840ull * 2160 || width * 2 > 4096 ||
      height * 2 > 4096) {
    throw std::invalid_argument("Invalid JaNai device, path or input budget");
  }
  state_ = std::make_unique<State>(GetRuntime(runtime_directory));
  auto& state = *state_;
  state.model = LockedAsset::Model(model);
  auto api = state.runtime->api;
  auto check = [&](OrtStatus* status) { state.runtime->CheckOrt(status); };
  ComPtr<IDXGIDevice> dxgi_device;
  ComPtr<IDXGIAdapter> adapter;
  DXGI_ADAPTER_DESC adapter_info{};
  Check(playback_device->QueryInterface(IID_PPV_ARGS(&dxgi_device)),
        "DXGI device");
  Check(dxgi_device->GetAdapter(&adapter), "Playback adapter");
  Check(adapter->GetDesc(&adapter_info), "Playback adapter description");
  ComPtr<IDXGIAdapter1> hardware_adapter;
  DXGI_ADAPTER_DESC1 hardware_info{};
  Check(adapter.As(&hardware_adapter), "Playback hardware adapter");
  Check(hardware_adapter->GetDesc1(&hardware_info), "Playback adapter flags");
  if (hardware_info.Flags & DXGI_ADAPTER_FLAG_SOFTWARE) {
    throw std::runtime_error("Software playback adapters cannot run JaNai");
  }
  state.luid = adapter_info.AdapterLuid;
  Check(D3D12CreateDevice(adapter.Get(), D3D_FEATURE_LEVEL_11_0,
                          IID_PPV_ARGS(&state.device)),
        "D3D12 playback adapter");
  D3D12_COMMAND_QUEUE_DESC queue_description{};
  queue_description.Type = D3D12_COMMAND_LIST_TYPE_DIRECT;
  Check(state.device->CreateCommandQueue(&queue_description,
                                         IID_PPV_ARGS(&state.queue)),
        "D3D12 inference queue");
  Check(state.runtime->create_device(state.device.Get(),
                                     DML_CREATE_DEVICE_FLAG_NONE,
                                     IID_PPV_ARGS(&state.dml_device)),
        "DirectML device");
  check(api->CreateEnv(ORT_LOGGING_LEVEL_WARNING, "BangumiToday.JaNai",
                       &state.environment));
  check(api->CreateSessionOptions(&state.options));
  check(api->SetSessionExecutionMode(state.options, ORT_SEQUENTIAL));
  check(api->DisableMemPattern(state.options));
  check(api->SetSessionGraphOptimizationLevel(state.options, ORT_ENABLE_ALL));
  check(api->AddSessionConfigEntry(state.options,
                                   "session.disable_cpu_ep_fallback", "1"));
  check(api->AddFreeDimensionOverrideByName(state.options, "height", height));
  check(api->AddFreeDimensionOverrideByName(state.options, "width", width));
  check(state.runtime->dml->SessionOptionsAppendExecutionProvider_DML1(
      state.options, state.dml_device.Get(), state.queue.Get()));
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
  state.input = TensorBuffer(state.device.Get(), state.input_size);
  state.output = TensorBuffer(state.device.Get(), state.output_size);
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
  Check(state.device->CreateFence(0, D3D12_FENCE_FLAG_NONE,
                                  IID_PPV_ARGS(&state.fence)),
        "Inference fence");
  state.completion = CreateEventW(nullptr, FALSE, FALSE, nullptr);
  if (!state.completion)
    throw std::runtime_error("Cannot create inference completion event");
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
        while (pending->fence->GetCompletedValue() < pending->last_ticket) {
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
ID3D12Device* DmlSession::device() const { return state_->device.Get(); }
ID3D12CommandQueue* DmlSession::queue() const { return state_->queue.Get(); }
uint64_t DmlSession::input_bytes() const { return state_->input_size; }
uint64_t DmlSession::output_bytes() const { return state_->output_size; }
LUID DmlSession::adapter_luid() const { return state_->luid; }

uint64_t DmlSession::Run() {
  std::lock_guard<std::mutex> lock(state_->mutex);
  if (state_->failed)
    throw std::runtime_error("JaNai session requires recovery");
  if (state_->last_ticket && !Complete(state_->last_ticket)) {
    throw std::runtime_error("Cannot reuse an in-flight JaNai tensor");
  }
  const auto ticket = state_->last_ticket + 1;
  state_->last_ticket = ticket;
  auto status = state_->runtime->api->RunWithBinding(state_->session, nullptr,
                                                     state_->binding);
  const auto signal = state_->queue->Signal(state_->fence.Get(), ticket);
  state_->failed = status || FAILED(signal);
  // Even a failed Run may have submitted GPU work. The fence and destructor's
  // lease cover those buffers before propagating the error to the coordinator.
  state_->runtime->CheckOrt(status);
  Check(signal, "Signal inference completion");
  return ticket;
}

bool DmlSession::Complete(uint64_t ticket) const {
  if (ticket > state_->last_ticket)
    throw std::invalid_argument("Unknown inference ticket");
  const auto completed = state_->fence->GetCompletedValue();
  if (completed == std::numeric_limits<uint64_t>::max()) {
    throw std::runtime_error("JaNai GPU device was removed");
  }
  return completed >= ticket;
}

void DmlSession::Wait(uint64_t ticket, uint32_t timeout_ms) {
  std::lock_guard<std::mutex> lock(state_->mutex);
  if (Complete(ticket)) return;
  Check(state_->fence->SetEventOnCompletion(ticket, state_->completion),
        "Wait inference fence");
  if (WaitForSingleObject(state_->completion, timeout_ms) != WAIT_OBJECT_0) {
    throw std::runtime_error("JaNai inference timed out");
  }
  if (!Complete(ticket))
    throw std::runtime_error("JaNai inference did not complete");
}
}  // namespace bangumi::inference
