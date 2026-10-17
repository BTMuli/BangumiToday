#include <d3d11_4.h>
#include <d3d12.h>
#include <dxgi1_4.h>
#include <wrl/client.h>

#include <chrono>
#include <cstdint>
#include <iostream>
#include <stdexcept>
#include <vector>

#include "gpu_copy_wait.h"
#include "gpu_test_support.h"
#include "inference/frame_budget.h"

namespace {
using namespace playback_gpu_test;
using Clock = std::chrono::steady_clock;

void CheckBudget() {
  using bangumi::inference::FrameBudgetMonitor;
  FrameBudgetMonitor budget;
  budget.Configure(24);
  for (int window = 0; window < 3; ++window) {
    for (int sample = 0; sample < 4; ++sample)
      budget.AddFrame(5, 500, 12);
    Require(budget.snapshot().window_frames == 48,
            "Skipped measurements lost completed frames");
    Require(!budget.snapshot().low_throughput &&
                !budget.snapshot().fallback_recommended,
            "Sparse GPU sampling falsely triggered fallback");
  }
  budget.Reset();
  for (int sample = 0; sample < 12; ++sample) budget.AddFrame(5, 500);
  Require(budget.snapshot().low_throughput &&
              budget.snapshot().fallback_recommended,
          "Real low throughput did not trigger fallback");
  budget.Reset();
  for (int sample = 0; sample < 60; ++sample) budget.AddFrame(50, 100, 2);
  Require(budget.snapshot().over_budget &&
              budget.snapshot().fallback_recommended,
          "Sampling hid sustained slow inference");
  budget.AddFrame(5, 2500, 1);
  Require(!budget.snapshot().fallback_recommended,
          "Idle time did not reset the budget");
  bool rejected = false;
  try {
    budget.AddFrame(1, 1, 0);
  } catch (const std::invalid_argument&) {
    rejected = true;
  }
  Require(rejected, "A sample must represent at least one completed frame");
}

void AwaitCopy(ID3D11DeviceContext* context, ID3D11Query* query,
               PlaybackGpuCopyWait& wait) {
  const auto deadline = Clock::now() + std::chrono::seconds(2);
  for (;;) {
    const auto result = context->GetData(query, nullptr, 0,
                                         D3D11_ASYNC_GETDATA_DONOTFLUSH);
    if (result == S_OK) return;
    Require(result == S_FALSE, "Copy completion query failed");
    Require(Clock::now() < deadline, "Copy completion timed out");
    wait.Wait(10);
  }
}

void CheckCopies(ID3D11Device* device, ID3D11DeviceContext* context,
                 bool events) {
  PlaybackGpuCopyWait wait;
  wait.SetContext(events ? context : nullptr);
  const D3D11_QUERY_DESC query_description{D3D11_QUERY_EVENT, 0};
  ComPtr<ID3D11Query> query;
  Check(device->CreateQuery(&query_description, &query));
  ComPtr<ID3D11Texture2D> first_snapshot;
  for (UINT frame = 0; frame < 24; ++frame) {
    D3D11_TEXTURE2D_DESC description{};
    description.Width = frame < 12 ? 64 : 257;
    description.Height = frame < 12 ? 48 : 129;
    description.MipLevels = description.ArraySize = 1;
    description.Format = DXGI_FORMAT_B8G8R8A8_UNORM;
    description.SampleDesc.Count = 1;
    description.Usage = D3D11_USAGE_DEFAULT;
    description.MiscFlags = D3D11_RESOURCE_MISC_SHARED;
    const uint32_t color = 0xff102030 + frame;
    std::vector<uint32_t> pixels(size_t{description.Width} * description.Height,
                                  color);
    D3D11_SUBRESOURCE_DATA initial{pixels.data(), description.Width * 4, 0};
    ComPtr<ID3D11Texture2D> source;
    ComPtr<ID3D11Texture2D> snapshot;
    Check(device->CreateTexture2D(&description, &initial, &source));
    Check(device->CreateTexture2D(&description, nullptr, &snapshot));
    context->CopyResource(snapshot.Get(), source.Get());
    context->End(query.Get());
    wait.Flush(context);
    AwaitCopy(context, query.Get(), wait);
    CheckPixels(device, context, snapshot.Get(), color);
    if (frame == 0) first_snapshot = snapshot;
  }
  CheckPixels(device, context, first_snapshot.Get(), 0xff102030);
}

void CheckPendingCopy(ID3D11Device* device, ID3D11DeviceContext* context) {
  ComPtr<ID3D11Device5> device5;
  ComPtr<ID3D11DeviceContext4> context4;
  Check(device->QueryInterface(IID_PPV_ARGS(&device5)));
  Check(context->QueryInterface(IID_PPV_ARGS(&context4)));
  ComPtr<ID3D11Fence> fence;
  Check(device5->CreateFence(0, D3D11_FENCE_FLAG_SHARED,
                              IID_PPV_ARGS(&fence)));
  ComPtr<IDXGIDevice> dxgi;
  ComPtr<IDXGIAdapter> adapter;
  Check(device->QueryInterface(IID_PPV_ARGS(&dxgi)));
  Check(dxgi->GetAdapter(&adapter));
  ComPtr<ID3D12Device> device12;
  Check(D3D12CreateDevice(adapter.Get(), D3D_FEATURE_LEVEL_11_0,
                          IID_PPV_ARGS(&device12)));
  HANDLE shared = nullptr;
  Check(fence->CreateSharedHandle(nullptr, GENERIC_ALL, nullptr, &shared));
  ComPtr<ID3D12Fence> cpu_fence;
  const auto opened = device12->OpenSharedHandle(shared, IID_PPV_ARGS(&cpu_fence));
  CloseHandle(shared);
  Check(opened);
  PlaybackGpuCopyWait wait;
  wait.SetContext(context);
  const D3D11_QUERY_DESC description{D3D11_QUERY_EVENT, 0};
  ComPtr<ID3D11Query> query;
  Check(device->CreateQuery(&description, &query));
  Check(context4->Wait(fence.Get(), 1));
  context->End(query.Get());
  wait.Flush(context);
  const auto started = Clock::now();
  wait.Wait(10);
  const auto elapsed = Clock::now() - started;
  const auto incomplete = context->GetData(query.Get(), nullptr, 0,
                                            D3D11_ASYNC_GETDATA_DONOTFLUSH);
  // Release the GPU even if an assertion fails; never leave its queue blocked.
  Check(cpu_fence->Signal(1));
  AwaitCopy(context, query.Get(), wait);
  Require(elapsed < std::chrono::seconds(1), "Event wait exceeded its deadline");
  Require(incomplete == S_FALSE, "A wakeup incorrectly completed pending work");
}
}  // namespace

int main() {
  try {
    CheckBudget();
    ComPtr<ID3D11Device> device;
    ComPtr<ID3D11DeviceContext> context;
    const D3D_FEATURE_LEVEL level = D3D_FEATURE_LEVEL_11_0;
    Check(D3D11CreateDevice(nullptr, D3D_DRIVER_TYPE_WARP, nullptr, 0, &level,
                            1, D3D11_SDK_VERSION, &device, nullptr, &context));
    CheckCopies(device.Get(), context.Get(), true);
    CheckCopies(device.Get(), context.Get(), false);
    CheckPendingCopy(device.Get(), context.Get());
    std::cout << "PASS: event and timer copies, immutable resized snapshots, "
                 "pending GPU deadline, sampled frame budget\n";
    return 0;
  } catch (const std::exception& error) {
    std::cerr << error.what() << '\n';
    return 1;
  }
}
