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
#include <stdexcept>
#include <string>
#include <thread>

#include "frame_contract.h"
#include "gpu_capabilities.h"
#include "trt_engine_cache.h"
#include "trusted_assets_data.h"

using namespace bangumi::inference;
using Microsoft::WRL::ComPtr;

namespace {
GpuCapabilities FindGpu() {
  ComPtr<IDXGIFactory1> factory;
  if (FAILED(CreateDXGIFactory1(IID_PPV_ARGS(&factory))))
    throw std::runtime_error("Cannot enumerate graphics adapters");
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
    if (gpu.cuda_device >= 0 && gpu.cuda_reason.empty() &&
        gpu.compute_major * 10 + gpu.compute_minor == 89 &&
        gpu.cuda_driver_version >= 13040)
      return gpu;
  }
  throw std::runtime_error("未找到支持 SM89 / CUDA 13.4 的 NVIDIA 显卡");
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
  struct Status {
    std::string phase = "preparing";
    int completed = 0;
    std::string task;
    std::string reason = "正在检测编译显卡";
    std::string log;
  };
  std::atomic<bool> cancelled{false};
  std::mutex mutex;
  Status status;
  std::string json;
  std::thread worker;

  bt_trt_precompile(std::filesystem::path bundle,
                    std::filesystem::path runtime,
                    std::filesystem::path cache) {
    worker = std::thread([this, bundle, runtime, cache] {
      Work(bundle, runtime, cache);
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
            const std::filesystem::path& cache) noexcept {
    try {
      if (!bundle.is_absolute() || !runtime.is_absolute() || !cache.is_absolute())
        throw std::invalid_argument("TensorRT preparation requires absolute paths");
      CheckCancelled();
      const auto gpu = FindGpu();
      // Use the same compiled model paths, padded frame plan, device identity,
      // locked assets and cache builder as playback; no parallel trtexec job.
      struct Task { const char* model; uint32_t width, height; const char* label; };
      const Task tasks[] = {
          {detail::kPerformancePath, 1280, 720, "720p · AI 流畅"},
          {detail::kBalancedPath, 1280, 720, "720p · AI 高质量"},
          {detail::kPerformancePath, 1920, 1080, "1080p · AI 流畅"},
          {detail::kBalancedPath, 1920, 1080, "1080p · AI 高质量"}};
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
      status.reason = "四个常用引擎已校验并缓存";
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
                                         const wchar_t* cache) {
  try {
    if (!bundle || !runtime || !cache) return nullptr;
    return new bt_trt_precompile(bundle, runtime, cache);
  } catch (...) { return nullptr; }
}

const char* bt_trt_precompile_poll(bt_trt_precompile* job) {
  if (!job) return nullptr;
  try {
    std::lock_guard<std::mutex> lock(job->mutex);
    const auto& s = job->status;
    job->json = "{\"phase\":" + Quote(s.phase) +
        ",\"completed\":" + std::to_string(s.completed) +
        ",\"total\":4,\"task\":" + Quote(s.task) +
        ",\"reason\":" + Quote(s.reason) + ",\"log\":" + Quote(s.log) + "}";
    return job->json.c_str();
  } catch (...) { return nullptr; }
}

void bt_trt_precompile_cancel(bt_trt_precompile* job) {
  if (job) job->cancelled = true;
}

void bt_trt_precompile_close(bt_trt_precompile* job) { delete job; }
}
