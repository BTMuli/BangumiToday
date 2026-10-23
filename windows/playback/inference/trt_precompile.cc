// Copyright (c) BangumiToday contributors. Licensed under the project MIT.
#include "trt_precompile.h"

#include <Windows.h>
#include <d3d11.h>
#include <dxgi1_2.h>
#include <wrl/client.h>

#include <atomic>
#include <chrono>
#include <filesystem>
#include <mutex>
#include <optional>
#include <stdexcept>
#include <string>
#include <thread>
#include <vector>

#include "frame_contract.h"
#include "gpu_capabilities.h"
#include "trt_assets_data.h"
#include "trt_engine_cache.h"
#include "trusted_assets_data.h"

using namespace bangumi::inference;
using Microsoft::WRL::ComPtr;

namespace {
GpuCapabilities FindGpu(int sm, const std::wstring& renderer) {
  if (!detail::SupportsSm(sm))
    throw std::runtime_error("TensorRT architecture is not in the pinned lock");
  ComPtr<IDXGIFactory1> factory;
  if (FAILED(CreateDXGIFactory1(IID_PPV_ARGS(&factory))))
    throw std::runtime_error("Cannot enumerate graphics adapters");
  std::optional<GpuCapabilities> compatible;
  for (UINT index = 0;; ++index) {
    ComPtr<IDXGIAdapter1> adapter;
    const HRESULT enumerated = factory->EnumAdapters1(index, &adapter);
    if (enumerated == DXGI_ERROR_NOT_FOUND) break;
    if (FAILED(enumerated))
      throw std::runtime_error("Cannot enumerate graphics adapter");
    DXGI_ADAPTER_DESC1 description{};
    if (FAILED(adapter->GetDesc1(&description)) ||
        description.VendorId != 0x10de ||
        (description.Flags & DXGI_ADAPTER_FLAG_SOFTWARE))
      continue;
    ComPtr<ID3D11Device> device;
    if (FAILED(D3D11CreateDevice(adapter.Get(), D3D_DRIVER_TYPE_UNKNOWN, nullptr,
                                 0, nullptr, 0, D3D11_SDK_VERSION, &device,
                                 nullptr, nullptr)))
      continue;
    const auto gpu = QueryGpuCapabilities(device.Get());
    if (gpu.cuda_device < 0 || !gpu.cuda_reason.empty() ||
        gpu.compute_major * 10 + gpu.compute_minor != sm ||
        gpu.cuda_driver_version < detail::kMinimumDriver)
      continue;
    if (renderer.empty() ||
        renderer.find(description.Description) != std::wstring::npos)
      return gpu;
    // A renderer string that names no adapter must not turn preparation into a
    // failure. Keep the first compatible device; a mismatched cache key only
    // costs the filter one build.
    if (!compatible) compatible = gpu;
  }
  if (compatible) return *compatible;
  throw std::runtime_error("未找到支持 SM" + std::to_string(sm) +
                           " / CUDA 13.4 的 NVIDIA 显卡");
}

std::string Utf8(const std::filesystem::path& path) {
  return path.u8string();
}

std::string Quote(const std::string& value) {
  std::string result = "\"";
  constexpr char hex[] = "0123456789abcdef";
  for (unsigned char ch : value) {
    if (ch == '\\' || ch == '"') {
      result += '\\';
      result += static_cast<char>(ch);
    } else if (ch < 0x20) {
      result += "\\u00";
      result += hex[ch >> 4];
      result += hex[ch & 15];
    } else {
      result += static_cast<char>(ch);
    }
  }
  return result + '"';
}
}  // namespace

struct bt_trt_precompile {
  struct Task { const char* model; uint32_t width, height; std::string label; };
  struct Status {
    std::string phase = "preparing";
    int completed = 0;
    int total = 0;
    std::string task;
    std::string reason = "正在检测编译显卡";
    std::string log;
    bool build_required = false;
  };
  std::atomic<bool> cancelled{false};
  std::mutex mutex;
  Status status;
  std::string json;
  std::thread worker;

  bt_trt_precompile(std::filesystem::path bundle,
                    std::filesystem::path runtime,
                    std::filesystem::path cache, int sm,
                    std::vector<Task> tasks, std::wstring renderer = {}) {
    status.total = static_cast<int>(tasks.size());
    worker = std::thread([this, bundle, runtime, cache, sm, tasks, renderer] {
      Work(bundle, runtime, cache, sm, tasks, renderer);
    });
  }
  ~bt_trt_precompile() {
    cancelled = true;
    if (worker.joinable()) worker.join();
  }

  void CheckCancelled() const {
    if (cancelled) throw std::runtime_error("引擎准备已取消");
  }

  void Work(const std::filesystem::path& bundle,
            const std::filesystem::path& runtime,
            const std::filesystem::path& cache, int sm,
            const std::vector<Task>& tasks,
            const std::wstring& renderer) noexcept {
    try {
      if (!bundle.is_absolute() || !runtime.is_absolute() || !cache.is_absolute())
        throw std::invalid_argument("TensorRT preparation requires absolute paths");
      CheckCancelled();
      const auto gpu = FindGpu(sm, renderer);
      // Use the same compiled model paths, padded frame plan, device identity,
      // locked assets and cache builder as playback; no parallel trtexec job.
      for (const auto& task : tasks) {
        CheckCancelled();
        {
          std::lock_guard<std::mutex> lock(mutex);
          status.task = task.label;
          status.reason = "正在检查引擎缓存";
          status.log.clear();
        }
        FrameDescription frame;
        frame.format = PixelFormat::kNv12;
        frame.matrix = ColorMatrix::kBt709;
        frame.range = ColorRange::kLimited;
        frame.coded_width = frame.visible_width = task.width;
        frame.coded_height = frame.visible_height = task.height;
        const auto plan = MakeFramePlan(frame);
        TrtEngineBuild build(runtime, cache,
            bundle / L"playback_inference" / std::filesystem::u8path(task.model),
            gpu, plan.model_width, plan.model_height);
        for (;;) {
          CheckCancelled();
          const auto progress = build.snapshot();
          {
            std::lock_guard<std::mutex> lock(mutex);
            status.reason = progress.reason;
            status.log = Utf8(progress.log);
            status.build_required |= progress.build_required;
          }
          if (progress.phase == TrtEngineBuild::Phase::kFailed)
            throw std::runtime_error(progress.reason);
          if (progress.phase == TrtEngineBuild::Phase::kReady) break;
          std::this_thread::sleep_for(std::chrono::milliseconds(100));
        }
        {
          std::lock_guard<std::mutex> lock(mutex);
          ++status.completed;
        }
      }
      CheckCancelled();
      std::lock_guard<std::mutex> lock(mutex);
      status.phase = "ready";
      status.reason = status.total == 4 ? "四个常用引擎已校验并缓存"
                                        : "当前模型引擎已校验并缓存";
    } catch (const std::exception& error) {
      std::lock_guard<std::mutex> lock(mutex);
      status.phase = cancelled ? "cancelled" : "failed";
      status.reason = error.what();
    } catch (...) {
      std::lock_guard<std::mutex> lock(mutex);
      status.phase = cancelled ? "cancelled" : "failed";
      status.reason = "Unexpected TensorRT precompilation failure";
    }
  }
};

extern "C" {
bt_trt_precompile* bt_trt_precompile_start(const wchar_t* bundle,
                                         const wchar_t* runtime,
                                         const wchar_t* cache, int sm) {
  try {
    if (!bundle || !runtime || !cache) return nullptr;
    return new bt_trt_precompile(bundle, runtime, cache, sm, {
        {detail::kBalancedPath, 1920, 1080, "1080p · AI 高质量"},
        {detail::kPerformancePath, 1920, 1080, "1080p · AI 流畅"},
        {detail::kBalancedPath, 1280, 720, "720p · AI 高质量"},
        {detail::kPerformancePath, 1280, 720, "720p · AI 流畅"}});
  } catch (...) { return nullptr; }
}

bt_trt_precompile* bt_trt_precompile_target_start(
    const wchar_t* bundle, const wchar_t* runtime, const wchar_t* cache, int sm,
    int slot, int width, int height, const wchar_t* renderer) {
  try {
    if (!bundle || !runtime || !cache || !renderer || !*renderer ||
        (slot != 1 && slot != 2) || width <= 0 || height <= 0 ||
        width > 1920 || height > 1080)
      return nullptr;
    return new bt_trt_precompile(bundle, runtime, cache, sm, {{
        slot == 1 ? detail::kPerformancePath : detail::kBalancedPath,
        static_cast<uint32_t>(width), static_cast<uint32_t>(height),
        std::to_string(width) + "×" + std::to_string(height) +
            (slot == 1 ? " · AI 流畅" : " · AI 高质量")}}, renderer);
  } catch (...) { return nullptr; }
}

const char* bt_trt_precompile_poll(bt_trt_precompile* job) {
  if (!job) return nullptr;
  try {
    std::lock_guard<std::mutex> lock(job->mutex);
    const auto& s = job->status;
    job->json = "{\"phase\":" + Quote(s.phase) +
        ",\"completed\":" + std::to_string(s.completed) +
        ",\"total\":" + std::to_string(s.total) + ",\"task\":" + Quote(s.task) +
        ",\"reason\":" + Quote(s.reason) + ",\"log\":" + Quote(s.log) +
        ",\"buildRequired\":" + (s.build_required ? "true" : "false") + "}";
    return job->json.c_str();
  } catch (...) { return nullptr; }
}

void bt_trt_precompile_cancel(bt_trt_precompile* job) {
  if (job) job->cancelled = true;
}

void bt_trt_precompile_close(bt_trt_precompile* job) { delete job; }
void bt_trt_precompile_clear_cache() {
  try { TrtPreparedEngine::ClearCache(); } catch (...) {}
}
}
