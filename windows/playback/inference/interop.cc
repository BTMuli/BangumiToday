// Copyright (c) BangumiToday contributors. Licensed under the project MIT
// license.
#include "interop.h"

#include <dxgi1_4.h>

#include <array>
#include <cstring>
#include <iomanip>
#include <limits>
#include <sstream>
#include <stdexcept>
#include <string>
#include <vector>

namespace bangumi::inference {
namespace {
using Microsoft::WRL::ComPtr;

std::string DeviceReason(HRESULT result) {
  const char* name = "HRESULT";
  switch (result) {
    case S_OK:
      name = "S_OK";
      break;
    case DXGI_ERROR_DEVICE_HUNG:
      name = "DXGI_ERROR_DEVICE_HUNG";
      break;
    case DXGI_ERROR_DEVICE_REMOVED:
      name = "DXGI_ERROR_DEVICE_REMOVED";
      break;
    case DXGI_ERROR_DEVICE_RESET:
      name = "DXGI_ERROR_DEVICE_RESET";
      break;
    case DXGI_ERROR_DRIVER_INTERNAL_ERROR:
      name = "DXGI_ERROR_DRIVER_INTERNAL_ERROR";
      break;
    case DXGI_ERROR_INVALID_CALL:
      name = "DXGI_ERROR_INVALID_CALL";
      break;
  }
  std::ostringstream text;
  text << name << " (0x" << std::uppercase << std::hex << std::setfill('0')
       << std::setw(8) << static_cast<uint32_t>(result) << ")";
  return text.str();
}

void Check(HRESULT result, const char* operation) {
  if (FAILED(result)) {
    throw std::runtime_error(std::string(operation) + ": HRESULT=" +
                             std::to_string(static_cast<uint32_t>(result)));
  }
}
}  // namespace

struct InteropContext::State final {
  struct Slot {
    ComPtr<ID3D12CommandAllocator> allocator;
    ComPtr<ID3D12GraphicsCommandList> list;
    uint64_t value = 0;
  };
  // Batches recorded by one frame may still be running when the next frame is
  // recorded, so the pool grows on demand. Beyond the cap the oldest batch is
  // waited for, which is the only place this class may block the caller.
  static constexpr size_t kMaxSlots = 8;
  ComPtr<ID3D11Device> playback_device;
  ComPtr<ID3D12Device> device;
  ComPtr<ID3D12CommandQueue> queue;
  ComPtr<ID3D12Fence> fence;
  ComPtr<ID3D11Fence> fence11;
  HANDLE fence_handle = nullptr;
  HANDLE event = nullptr;
  LUID luid{};
  uint64_t value = 0;
  std::vector<Slot> slots;
  ComPtr<ID3D12QueryHeap> query_heap;
  std::array<ComPtr<ID3D12Resource>, InteropContext::kTimestampBuffers>
      timestamp_buffers;
  uint64_t timestamp_frequency = 0;

  uint64_t CompletedValue() const {
    const uint64_t completed = fence->GetCompletedValue();
    if (completed == std::numeric_limits<uint64_t>::max()) {
      throw std::runtime_error(
          "JaNai GPU device was removed: D3D12=" +
          DeviceReason(device->GetDeviceRemovedReason()) + "; D3D11=" +
          DeviceReason(playback_device->GetDeviceRemovedReason()));
    }
    return completed;
  }
};

std::unique_ptr<InteropContext> InteropContext::Create(
    ID3D11Device* playback_device) {
  if (!playback_device) throw std::invalid_argument("Missing playback device");
  auto context = std::unique_ptr<InteropContext>(new InteropContext());
  context->state_ = std::make_unique<State>();
  auto& state = *context->state_;
  state.playback_device = playback_device;

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
  if (hardware_info.Flags & DXGI_ADAPTER_FLAG_SOFTWARE)
    throw std::runtime_error("Software playback adapters cannot run JaNai");
  state.luid = adapter_info.AdapterLuid;

  Check(D3D12CreateDevice(adapter.Get(), D3D_FEATURE_LEVEL_11_0,
                          IID_PPV_ARGS(&state.device)),
        "D3D12 playback adapter");
  D3D12_COMMAND_QUEUE_DESC queue_description{};
  queue_description.Type = D3D12_COMMAND_LIST_TYPE_DIRECT;
  Check(state.device->CreateCommandQueue(&queue_description,
                                         IID_PPV_ARGS(&state.queue)),
        "D3D12 command queue");
  Check(state.device->CreateFence(0, D3D12_FENCE_FLAG_SHARED,
                                  IID_PPV_ARGS(&state.fence)),
        "Shared D3D12 fence");
  Check(state.device->CreateSharedHandle(state.fence.Get(), nullptr, GENERIC_ALL,
                                         nullptr, &state.fence_handle),
        "Share the D3D12 fence");
  ComPtr<ID3D11Device5> device5;
  Check(playback_device->QueryInterface(IID_PPV_ARGS(&device5)),
        "ID3D11Device5 for shared fences");
  Check(device5->OpenSharedFence(state.fence_handle,
                                 IID_PPV_ARGS(&state.fence11)),
        "Open the shared fence on D3D11");

  state.slots.resize(1);
  for (auto& slot : state.slots) {
    Check(state.device->CreateCommandAllocator(
              D3D12_COMMAND_LIST_TYPE_DIRECT, IID_PPV_ARGS(&slot.allocator)),
          "Create D3D12 command allocator");
    Check(state.device->CreateCommandList(0, D3D12_COMMAND_LIST_TYPE_DIRECT,
                                          slot.allocator.Get(), nullptr,
                                          IID_PPV_ARGS(&slot.list)),
          "Create D3D12 command list");
    Check(slot.list->Close(), "Close a fresh D3D12 command list");
  }
  state.event = CreateEventW(nullptr, FALSE, FALSE, nullptr);
  if (!state.event) throw std::runtime_error("Cannot create the fence event");

  // GPU timestamps are optional: a queue that cannot report a frequency simply
  // leaves the diagnostics without GPU numbers.
  if (SUCCEEDED(state.queue->GetTimestampFrequency(&state.timestamp_frequency)) &&
      state.timestamp_frequency > 0) {
    D3D12_QUERY_HEAP_DESC heap_description{};
    heap_description.Type = D3D12_QUERY_HEAP_TYPE_TIMESTAMP;
    heap_description.Count = InteropContext::kTimestampSlots;
    if (FAILED(state.device->CreateQueryHeap(&heap_description,
                                             IID_PPV_ARGS(&state.query_heap)))) {
      state.timestamp_frequency = 0;
    } else {
      D3D12_HEAP_PROPERTIES heap{};
      heap.Type = D3D12_HEAP_TYPE_READBACK;
      D3D12_RESOURCE_DESC description{};
      description.Dimension = D3D12_RESOURCE_DIMENSION_BUFFER;
      description.Width = InteropContext::kTimestampSlots * sizeof(uint64_t);
      description.Height = 1;
      description.DepthOrArraySize = 1;
      description.MipLevels = 1;
      description.SampleDesc.Count = 1;
      description.Layout = D3D12_TEXTURE_LAYOUT_ROW_MAJOR;
      for (auto& buffer : state.timestamp_buffers) {
        if (FAILED(state.device->CreateCommittedResource(
                &heap, D3D12_HEAP_FLAG_NONE, &description,
                D3D12_RESOURCE_STATE_COPY_DEST, nullptr,
                IID_PPV_ARGS(&buffer)))) {
          state.timestamp_frequency = 0;
          state.query_heap.Reset();
          break;
        }
      }
    }
  }
  return context;
}

bool InteropContext::timestamps_supported() const {
  return state_->timestamp_frequency > 0 && state_->query_heap != nullptr;
}

void InteropContext::WriteTimestamp(ID3D12GraphicsCommandList* list,
                                    uint32_t slot) {
  if (!timestamps_supported() || !list) return;
  if (slot >= kTimestampSlots)
    throw std::invalid_argument("Unknown timestamp slot");
  list->EndQuery(state_->query_heap.Get(), D3D12_QUERY_TYPE_TIMESTAMP, slot);
}

void InteropContext::ResolveTimestamps(ID3D12GraphicsCommandList* list,
                                       uint32_t first_slot, uint32_t count,
                                       uint32_t buffer) {
  if (!timestamps_supported() || !list) return;
  if (first_slot + count > kTimestampSlots || buffer >= kTimestampBuffers)
    throw std::invalid_argument("Unknown timestamp range");
  list->ResolveQueryData(state_->query_heap.Get(), D3D12_QUERY_TYPE_TIMESTAMP,
                         first_slot, count,
                         state_->timestamp_buffers[buffer].Get(), 0);
}

bool InteropContext::ReadTimestamps(uint64_t value, uint32_t buffer,
                                    uint32_t count,
                                    std::vector<uint64_t>* ticks) {
  if (!timestamps_supported() || !ticks)
    throw std::invalid_argument("Timestamps are unavailable");
  if (buffer >= kTimestampBuffers || count > kTimestampSlots)
    throw std::invalid_argument("Unknown timestamp range");
  if (!Complete(value)) return false;
  void* mapped = nullptr;
  D3D12_RANGE range{0, count * sizeof(uint64_t)};
  if (FAILED(state_->timestamp_buffers[buffer]->Map(0, &range, &mapped)))
    return false;
  ticks->assign(count, 0);
  std::memcpy(ticks->data(), mapped, count * sizeof(uint64_t));
  D3D12_RANGE written{0, 0};
  state_->timestamp_buffers[buffer]->Unmap(0, &written);
  return true;
}

double InteropContext::MillisecondsBetween(uint64_t begin, uint64_t end) const {
  if (!timestamps_supported() || end < begin) return 0.0;
  return static_cast<double>(end - begin) * 1000.0 /
         static_cast<double>(state_->timestamp_frequency);
}
InteropContext::~InteropContext() {
  if (!state_) return;
  if (state_->event) CloseHandle(state_->event);
  if (state_->fence_handle) CloseHandle(state_->fence_handle);
}

ID3D12Device* InteropContext::device() const { return state_->device.Get(); }
ID3D12CommandQueue* InteropContext::queue() const {
  return state_->queue.Get();
}
ID3D12Fence* InteropContext::fence() const { return state_->fence.Get(); }
LUID InteropContext::adapter_luid() const { return state_->luid; }

uint64_t InteropContext::SignalQueue() {
  auto& state = *state_;
  const uint64_t value = ++state.value;
  Check(state.queue->Signal(state.fence.Get(), value),
        "Signal the shared fence");
  return value;
}

uint64_t InteropContext::SignalFromD3D11(ID3D11DeviceContext4* context4) {
  if (!context4) throw std::invalid_argument("Missing D3D11 context4");
  auto& state = *state_;
  const uint64_t value = ++state.value;
  Check(context4->Signal(state.fence11.Get(), value),
        "Signal the shared fence from D3D11");
  return value;
}

void InteropContext::WaitOnD3D11(ID3D11DeviceContext4* context4,
                                 uint64_t value) {
  if (!context4) throw std::invalid_argument("Missing D3D11 context4");
  if (value == 0) return;
  Check(context4->Wait(state_->fence11.Get(), value),
        "Wait for shared D3D12 work on D3D11");
}

uint64_t InteropContext::Submit(
    uint64_t wait_value,
    const std::function<void(ID3D12GraphicsCommandList*)>& record) {
  auto& state = *state_;
  if (wait_value > state.value)
    throw std::invalid_argument("Unknown interop fence value");
  State::Slot* slot = nullptr;
  for (auto& candidate : state.slots) {
    if (candidate.value == 0 || state.CompletedValue() >= candidate.value) {
      slot = &candidate;
      break;
    }
  }
  if (!slot) {
    if (state.slots.size() < State::kMaxSlots) {
      state.slots.emplace_back();
      slot = &state.slots.back();
      Check(state.device->CreateCommandAllocator(
                D3D12_COMMAND_LIST_TYPE_DIRECT, IID_PPV_ARGS(&slot->allocator)),
            "Create D3D12 command allocator");
      Check(state.device->CreateCommandList(0, D3D12_COMMAND_LIST_TYPE_DIRECT,
                                            slot->allocator.Get(), nullptr,
                                            IID_PPV_ARGS(&slot->list)),
            "Create D3D12 command list");
      // A new list starts in the recording state and must be closed before its
      // allocator can be reset.
      Check(slot->list->Close(), "Close a fresh D3D12 command list");
    } else {
      // Backpressure: every allocation is still owned by the GPU, which means
      // the caller is far ahead of the device. Waiting for the oldest batch is
      // the only place this class may block, and it stays bounded.
      State::Slot* oldest = &state.slots.front();
      for (auto& candidate : state.slots) {
        if (candidate.value < oldest->value) oldest = &candidate;
      }
      Wait(oldest->value, 5000);
      slot = oldest;
    }
  }
  Check(slot->allocator->Reset(), "Reset the D3D12 command allocator");
  Check(slot->list->Reset(slot->allocator.Get(), nullptr),
        "Reset the D3D12 command list");
  record(slot->list.Get());
  Check(slot->list->Close(), "Close the D3D12 command list");
  if (wait_value)
    Check(state.queue->Wait(state.fence.Get(), wait_value),
          "Wait for shared D3D11 work on D3D12");
  ID3D12CommandList* lists[] = {slot->list.Get()};
  state.queue->ExecuteCommandLists(1, lists);
  const uint64_t value = ++state.value;
  Check(state.queue->Signal(state.fence.Get(), value),
        "Signal the shared fence");
  slot->value = value;
  return value;
}

bool InteropContext::Complete(uint64_t value) const {
  if (value > state_->value)
    throw std::invalid_argument("Unknown interop fence value");
  if (value == 0) return true;
  return state_->CompletedValue() >= value;
}

void InteropContext::Wait(uint64_t value, uint32_t timeout_ms) {
  auto& state = *state_;
  if (Complete(value)) return;
  if (value > state.value)
    throw std::invalid_argument("Unknown interop fence value");
  Check(state.fence->SetEventOnCompletion(value, state.event),
        "Wait for the shared fence");
  if (WaitForSingleObject(state.event, timeout_ms) != WAIT_OBJECT_0)
    throw std::runtime_error("JaNai frame did not complete in time");
  if (!Complete(value))
    throw std::runtime_error("JaNai frame did not complete");
}

uint64_t InteropContext::last_submitted() const { return state_->value; }

}  // namespace bangumi::inference
