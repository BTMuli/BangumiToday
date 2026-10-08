// Copyright (c) BangumiToday contributors. Licensed under the project MIT
// license.
//
// AnimeJaNai shim: the DLL the LGPL mpv filter loads (see aji_abi.h). It owns
// the project's frame bridge and translates the filter's calls into pipeline
// work, so the mpv side stays the upstream filter and this side stays the
// project's own code.
//
// Configuration file (the filter's `conf` option) is line based:
//
//   # comments start with '#'
//   runtime_dir=playback_inference        ; onnxruntime.dll / DirectML.dll
//   model_dir=models                      ; where the .onnx files live
//   default_slot=1
//   slot1=2x_AnimeJaNai_HD_V3.1_Performance_..._fp16.onnx
//   slot2=2x_AnimeJaNai_HD_V3.1_Balanced_..._fp16.onnx
//
// Relative paths resolve against the configuration file's directory;
// `runtime_dir` falls back to the shim DLL's directory. Slot 1 is "smooth"
// (Performance) and slot 2 "high quality" (Balanced) by convention.
#include <ShlObj.h>
#include <Windows.h>
#include <d3d11.h>
#include <wrl/client.h>

#include <algorithm>
#include <cctype>
#include <chrono>
#include <cmath>
#include <cstring>
#include <filesystem>
#include <fstream>
#include <map>
#include <memory>
#include <mutex>
#include <sstream>
#include <stdexcept>
#include <string>
#include <vector>

#include "aji_abi.h"
#include "frame_contract.h"
#include "frame_pipeline.h"
#include "gpu_capabilities.h"
#include "trt_engine_cache.h"

using Microsoft::WRL::ComPtr;
using namespace bangumi::inference;

namespace {

// mpv message levels, used for the log bridge: 1 error, 2 warning, 3 info.
constexpr int kLogError = 1;
constexpr int kLogWarning = 2;
constexpr int kLogInfo = 3;

std::string Trim(std::string value) {
  const auto not_space = [](unsigned char character) {
    return !std::isspace(character);
  };
  value.erase(value.begin(),
              std::find_if(value.begin(), value.end(), not_space));
  value.erase(std::find_if(value.rbegin(), value.rend(), not_space).base(),
              value.end());
  return value;
}

std::string FromWide(const std::wstring& value) {
  if (value.empty()) return {};
  const int length = WideCharToMultiByte(CP_UTF8, 0, value.c_str(),
                                         static_cast<int>(value.size()),
                                         nullptr, 0, nullptr, nullptr);
  if (length <= 0) return {};
  std::string result(static_cast<size_t>(length), '\0');
  WideCharToMultiByte(CP_UTF8, 0, value.c_str(), static_cast<int>(value.size()),
                      result.data(), length, nullptr, nullptr);
  return result;
}

std::filesystem::path ModuleDirectory() {
  HMODULE module = nullptr;
  if (!GetModuleHandleExW(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS |
                              GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT,
                          reinterpret_cast<LPCWSTR>(&ModuleDirectory),
                          &module)) {
    return {};
  }
  std::vector<wchar_t> buffer(32768);
  const DWORD count = GetModuleFileNameW(module, buffer.data(),
                                         static_cast<DWORD>(buffer.size()));
  if (!count || count >= buffer.size()) return {};
  return std::filesystem::path(buffer.data()).parent_path();
}

// The status snapshot needs a writable location: the installed player directory
// is read-only for packaged builds, so the default lives in the per-user local
// application data directory and a `stats` key in the configuration can still
// override it.
std::filesystem::path DefaultStatsPath() {
  PWSTR folder = nullptr;
  if (FAILED(SHGetKnownFolderPath(FOLDERID_LocalAppData, 0, nullptr, &folder)))
    return {};
  std::filesystem::path path(folder);
  CoTaskMemFree(folder);
  path /= L"BangumiToday";
  std::error_code error;
  std::filesystem::create_directories(path, error);
  return path / L"animejanai-stats.txt";
}

}  // namespace

struct aji_ctx {
  aji_log_fn log = nullptr;
  void* log_opaque = nullptr;
  ComPtr<ID3D11Device> device;
  ComPtr<ID3D11DeviceContext> context;

  std::filesystem::path config_path;
  std::filesystem::path runtime_dir;
  std::filesystem::path model_dir;
  // A missing backend key in an older configuration must not enable DirectML.
  // backend=directml is retained only as an explicit diagnostic override.
  bool trt_enabled = true;
  bool trt_failed = false;
  bool build_notified = false;
  int build_slot = 0, build_width = 0, build_height = 0;
  std::filesystem::path trt_dir;
  std::filesystem::path engine_cache;
  std::unique_ptr<TrtEngineBuild> build;
  std::filesystem::path trt_engine;
  std::shared_ptr<TrtResources> trt_resources;
  GpuCapabilities gpu;
  std::string backend_reason;
  // Low-frequency diagnostics snapshot (config key `stats`). The hot path only
  // updates counters; the file is rewritten at most once per second.
  std::filesystem::path stats_path;
  uint64_t frames_inferred = 0;
  uint64_t frames_failed = 0;
  double last_gpu_ms = 0;
  std::chrono::steady_clock::time_point stats_written;
  std::map<int, std::filesystem::path> slot_models;
  int slot = 1;

  // Last configure() request; the pipeline is created once the format is known
  // from a frame.
  int width = 0;
  int height = 0;
  double fps = 0;

  std::unique_ptr<FramePipeline> pipeline;
  PixelFormat pipeline_format = PixelFormat::kNone;
  FramePlan plan;
  ColorConversion color;

  // Input plane views, cached per texture.
  ComPtr<ID3D11Texture2D> input_texture;
  ComPtr<ID3D11ShaderResourceView> luma_view;
  ComPtr<ID3D11ShaderResourceView> chroma_view;
  int input_slice = 0;

  uint64_t last_ticket = 0;
  std::string log_text;
  std::string last_error;
  // Why the current phase is not upscaling, published in the status snapshot so
  // the player can explain a silent passthrough without reading the log.
  std::string status_reason;
  mutable std::mutex mutex;

  void Log(int level, const std::string& message) {
    if (level <= kLogWarning) last_error = message;
    if (log) log(log_opaque, level, message.c_str());
  }
};

namespace {

bool ParseConfig(aji_ctx& state, const std::filesystem::path& path) {
  std::ifstream stream(path, std::ios::binary);
  if (!stream) return false;
  std::string contents((std::istreambuf_iterator<char>(stream)),
                       std::istreambuf_iterator<char>());
  // Configuration files authored by editors or PowerShell often start with a
  // UTF-8 byte order mark; it would otherwise become part of the first key.
  if (contents.size() >= 3 && static_cast<unsigned char>(contents[0]) == 0xEF &&
      static_cast<unsigned char>(contents[1]) == 0xBB &&
      static_cast<unsigned char>(contents[2]) == 0xBF) {
    contents.erase(0, 3);
  }
  std::istringstream lines(contents);
  const std::filesystem::path base = path.parent_path();
  // Slot values may be bare file names; they are resolved after parsing so a
  // later model_dir wins over the configuration file's directory.
  std::map<int, std::string> slot_text;
  std::string line;
  int line_number = 0;
  while (std::getline(lines, line)) {
    ++line_number;
    const std::string trimmed = Trim(line);
    if (trimmed.empty() || trimmed[0] == '#' || trimmed[0] == ';') continue;
    const size_t separator = trimmed.find('=');
    if (separator == std::string::npos) {
      state.Log(kLogWarning, "Ignoring malformed shim configuration line " +
                                 std::to_string(line_number));
      continue;
    }
    const std::string key = Trim(trimmed.substr(0, separator));
    const std::string value = Trim(trimmed.substr(separator + 1));
    if (value.empty()) continue;
    const auto resolve = [&](const std::string& text) {
      std::filesystem::path candidate = std::filesystem::u8path(text);
      if (candidate.is_relative()) candidate = base / candidate;
      return candidate;
    };
    if (key == "runtime_dir") {
      state.runtime_dir = resolve(value);
    } else if (key == "model_dir") {
      state.model_dir = resolve(value);
    } else if (key == "stats") {
      state.stats_path = resolve(value);
    } else if (key == "backend") {
      if (value != "directml" && value != "tensorrt")
        throw std::invalid_argument("Unknown AnimeJaNai backend");
      state.trt_enabled = value == "tensorrt";
    } else if (key == "trt_dir") {
      state.trt_dir = resolve(value);
    } else if (key == "engine_cache") {
      state.engine_cache = resolve(value);
    } else if (key == "default_slot") {
      state.slot = std::atoi(value.c_str());
    } else if (key.rfind("slot", 0) == 0 && key.size() > 4) {
      const int slot = std::atoi(key.c_str() + 4);
      if (slot > 0) slot_text[slot] = value;
    } else {
      state.Log(kLogWarning, "Ignoring unknown shim configuration key: " + key);
    }
  }
  const std::filesystem::path models =
      state.model_dir.empty() ? base : state.model_dir;
  for (const auto& entry : slot_text) {
    std::filesystem::path candidate = std::filesystem::u8path(entry.second);
    if (candidate.is_relative()) candidate = models / candidate;
    state.slot_models[entry.first] = candidate;
  }
  return true;
}

PixelFormat ToPixelFormat(int format) {
  switch (format) {
    case AJI_FMT_NV12:
      return PixelFormat::kNv12;
    case AJI_FMT_P010:
      return PixelFormat::kP010;
    default:
      return PixelFormat::kNone;
  }
}

bool CreatePlaneViews(aji_ctx& state, ID3D11Texture2D* texture,
                      PixelFormat format) {
  if (state.input_texture.Get() == texture) return true;
  ComPtr<ID3D11ShaderResourceView> luma;
  ComPtr<ID3D11ShaderResourceView> chroma;
  D3D11_SHADER_RESOURCE_VIEW_DESC description{};
  description.ViewDimension = D3D11_SRV_DIMENSION_TEXTURE2D;
  description.Texture2D.MipLevels = 1;
  // D3D11 has no plane slice field: the view format selects the plane of a
  // planar texture (R8/R16 is luma, R8G8/R16G16 is chroma).
  description.Format = format == PixelFormat::kP010 ? DXGI_FORMAT_R16_UNORM
                                                    : DXGI_FORMAT_R8_UNORM;
  if (FAILED(
          state.device->CreateShaderResourceView(texture, &description, &luma)))
    return false;
  description.Format = format == PixelFormat::kP010 ? DXGI_FORMAT_R16G16_UNORM
                                                    : DXGI_FORMAT_R8G8_UNORM;
  if (FAILED(state.device->CreateShaderResourceView(texture, &description,
                                                    &chroma)))
    return false;
  state.input_texture = texture;
  state.luma_view = luma;
  state.chroma_view = chroma;
  return true;
}

void DescribePlan(aji_ctx& state) {
  const std::filesystem::path model = state.slot_models.count(state.slot)
                                          ? state.slot_models[state.slot]
                                          : std::filesystem::path();
  std::string text;
  text += "BangumiToday AnimeJaNai shim\n";
  text += "  api version: " + std::to_string(AJI_API_VERSION) + "\n";
  text += !state.pipeline ? "  backend: none (no active inference)\n"
              : state.pipeline->uses_tensorrt()
                    ? "  backend: TensorRT (CUDA / D3D11)\n"
                    : "  backend: DirectML (diagnostic override)\n";
  if (!state.backend_reason.empty())
    text += "  TensorRT: " + state.backend_reason + "\n";
  text += "  slot: " + std::to_string(state.slot) + "\n";
  text += "  model: " + FromWide(model.filename().wstring()) + "\n";
  if (state.pipeline) {
    if (state.pipeline->uses_tensorrt())
      text += state.pipeline->uses_cuda_graph()
                  ? "  CUDA graph: enabled\n"
                  : "  CUDA graph: unavailable (ordinary TensorRT enqueue)\n";
    text += "  input: " + std::to_string(state.plan.visible_width) + "x" +
            std::to_string(state.plan.visible_height) + " (" +
            (state.pipeline_format == PixelFormat::kP010 ? "P010" : "NV12") +
            ", BT.709 limited)\n";
    text += "  model input: " + std::to_string(state.plan.model_width) + "x" +
            std::to_string(state.plan.model_height) + " (padded)\n";
    text += "  output: " + std::to_string(state.plan.visible_width * 2) + "x" +
            std::to_string(state.plan.visible_height * 2) + "\n";
  } else {
    text += "  state: passthrough (no active chain)\n";
  }
  state.log_text = text;
}

// Writes the fixed-schema status snapshot the coordinator and the info panel
// read. Only counters are updated on the hot path; the file is rewritten at
// most once per second and replaced atomically.
void PublishStats(aji_ctx& state, const char* phase, bool force) noexcept try {
  if (state.stats_path.empty()) return;
  const auto now = std::chrono::steady_clock::now();
  if (!force &&
      state.stats_written != std::chrono::steady_clock::time_point{} &&
      now - state.stats_written < std::chrono::seconds(1))
    return;
  state.stats_written = now;
  std::filesystem::path temporary = state.stats_path;
  temporary += L".tmp";
  {
    std::ofstream stream(temporary, std::ios::binary | std::ios::trunc);
    if (!stream) return;
    // Fixed schema, one field per line: simple to parse and to extend.
    stream << "schemaVersion=1\n";
    stream << "phase=" << (phase ? phase : "unknown") << "\n";
    stream << "backend=" << (!state.pipeline ? "none"
                                : state.pipeline->uses_tensorrt()
                                      ? "tensorrt" : "directml") << "\n";
    stream << "backendReason=" << state.backend_reason << "\n";
    stream << "gpuName=" << FromWide(state.gpu.name) << "\n";
    stream << "gpuVendor=" << state.gpu.vendor << "\n";
    stream << "gpuSm=" << state.gpu.compute_major * 10 + state.gpu.compute_minor << "\n";
    stream << "gpuDriver=" << state.gpu.cuda_driver_version << "\n";
    stream << "buildLog=" << (state.build
        ? FromWide(state.build->snapshot().log.wstring()) : std::string()) << "\n";
    stream << "engine=" << FromWide(state.trt_engine.filename().wstring()) << "\n";
    stream << "slot=" << state.slot << "\n";
    stream << "model="
           << (state.slot_models.count(state.slot)
                   ? FromWide(
                         state.slot_models[state.slot].filename().wstring())
                   : std::string())
           << "\n";
    // The frame plan only exists once a pipeline is built from a real frame, so
    // before that the snapshot reports the configured geometry and leaves the
    // padded model input unknown.
    const uint32_t visible_width = state.plan.visible_width
                                       ? state.plan.visible_width
                                       : static_cast<uint32_t>(state.width);
    const uint32_t visible_height = state.plan.visible_height
                                        ? state.plan.visible_height
                                        : static_cast<uint32_t>(state.height);
    stream << "input=" << state.width << "x" << state.height << "\n";
    stream << "modelInput=";
    if (state.plan.model_width)
      stream << state.plan.model_width << "x" << state.plan.model_height;
    stream << "\n";
    stream << "output=" << visible_width * 2 << "x" << visible_height * 2
           << "\n";
    stream << "framesInferred=" << state.frames_inferred << "\n";
    stream << "framesFailed=" << state.frames_failed << "\n";
    stream << "lastGpuMs=" << state.last_gpu_ms << "\n";
    stream << "ticket=" << state.last_ticket << "\n";
    stream << "reason=" << state.status_reason << "\n";
  }
  if (!MoveFileExW(temporary.c_str(), state.stats_path.c_str(),
                   MOVEFILE_REPLACE_EXISTING)) {
    std::error_code error;
    std::filesystem::remove(temporary, error);
  }
} catch (...) {
  // Diagnostics must never make an inference call cross the C ABI with an
  // exception, including when the user's writable directory is unavailable.
}

int Fail(aji_ctx* state, const char* reason) noexcept {
  if (state) {
    try {
      std::lock_guard<std::mutex> lock(state->mutex);
      ++state->frames_failed;
      state->status_reason = reason;
      state->last_error = reason;
      state->Log(kLogError, reason);
      PublishStats(*state, "failed", true);
    } catch (...) {
    }
  }
  return AJI_ERR;
}

}  // namespace

extern "C" {

AJI_EXPORT aji_ctx* aji_create(const aji_create_params* params) try {
  if (!params || params->api_version != AJI_API_VERSION) return nullptr;
  auto state = std::make_unique<aji_ctx>();
  state->log = params->log;
  state->log_opaque = params->log_opaque;
  state->slot = params->slot > 0 ? params->slot : 1;
  if (!params->d3d11_device) {
    state->Log(kLogError, "The shim requires the caller's ID3D11Device");
    return nullptr;
  }
  state->device = static_cast<ID3D11Device*>(params->d3d11_device);
  state->device->GetImmediateContext(&state->context);
  if (!state->context) {
    state->Log(kLogError, "The caller's D3D11 device has no immediate context");
    return nullptr;
  }

  const std::filesystem::path module = ModuleDirectory();
  state->runtime_dir = module;
  // The filter usually needs no path options at all: a configuration file next
  // to this DLL (and models next to it) is the shipped layout, which also keeps
  // Windows paths out of mpv's `:`-separated filter option syntax.
  std::filesystem::path config_source;
  if (params->conf_path && *params->conf_path) {
    config_source = std::filesystem::u8path(params->conf_path);
    std::error_code probe_error;
    if (config_source.is_relative() ||
        !std::filesystem::exists(config_source, probe_error)) {
      // mpv resolves the filter's conf option against its working directory,
      // which is not necessarily the player directory. The shipped layout keeps
      // the configuration next to this DLL, so prefer that copy.
      const std::filesystem::path beside_module = module / config_source.filename();
      std::error_code beside_error;
      if (!module.empty() &&
          std::filesystem::exists(beside_module, beside_error)) {
        config_source = beside_module;
      } else if (config_source.is_relative()) {
        config_source = std::filesystem::absolute(config_source);
      }
    }
  } else if (!module.empty() &&
             std::filesystem::exists(module / L"animejanai.conf")) {
    config_source = module / L"animejanai.conf";
  }
  if (!config_source.empty()) {
    if (!config_source.is_absolute())
      config_source = std::filesystem::absolute(config_source);
    state->config_path = config_source;
    if (!ParseConfig(*state, config_source)) {
      state->Log(kLogError, "Cannot read the shim configuration: " +
                                FromWide(config_source.wstring()));
      return nullptr;
    }
    // default_slot is only a default; an explicit filter slot always wins.
    if (params->slot > 0) state->slot = params->slot;
    if (state->slot > 0 && !state->slot_models.count(state->slot))
      state->Log(kLogWarning, "Slot " + std::to_string(state->slot) +
                                  " is not configured; the shim will pass "
                                  "through until it is");
  } else {
    state->Log(kLogWarning,
               "No shim configuration was found; the shim cannot load models");
  }
  if (params->model_dir && *params->model_dir)
    state->model_dir = std::filesystem::u8path(params->model_dir);
  if (state->model_dir.empty()) {
    state->model_dir = state->config_path.empty()
                           ? module / L"models"
                           : state->config_path.parent_path() / L"models";
  }
  if (state->runtime_dir.empty()) state->runtime_dir = module;
  if (state->stats_path.empty()) state->stats_path = DefaultStatsPath();
  // Optional components and engines live in writable per-user data, never in
  // WindowsApps or the application bundle. Production AI requires TensorRT;
  // missing components leave ordinary playback available.
  const auto writable = DefaultStatsPath().parent_path() / L"playback-tensorrt";
  if (state->trt_dir.empty())
    state->trt_dir = writable / L"11.3.0.99" / L"sm89";
  if (state->engine_cache.empty()) state->engine_cache = writable / L"engines";
  DescribePlan(*state);
  state->Log(kLogInfo, "AnimeJaNai shim created (runtime " +
                           FromWide(state->runtime_dir.wstring()) + ")");
  return state.release();
} catch (const std::exception& error) {
  try {
    if (params && params->log)
      params->log(params->log_opaque, kLogError, error.what());
  } catch (...) {
  }
  return nullptr;
} catch (...) {
  return nullptr;
}

AJI_EXPORT int aji_set_slot(aji_ctx* c, int slot) try {
  if (!c) return AJI_ERR;
  std::lock_guard<std::mutex> lock(c->mutex);
  if (slot <= 0) {
    c->slot = slot;
    c->Log(kLogInfo, "Shim slot cleared (passthrough)");
    return AJI_OK;
  }
  c->slot = slot;
  c->Log(c->slot_models.count(slot) ? kLogInfo : kLogWarning,
         "Shim slot set to " + std::to_string(slot));
  return AJI_OK;
} catch (const std::exception& error) {
  return Fail(c, error.what());
} catch (...) {
  return Fail(c, "Unexpected slot configuration failure");
}

AJI_EXPORT int aji_configure(aji_ctx* c, int w, int h, double fps, int* out_w,
                             int* out_h) try {
  if (!c || !out_w || !out_h) return AJI_ERR;
  std::lock_guard<std::mutex> lock(c->mutex);
  *out_w = w;
  *out_h = h;
  c->pipeline.reset();
  c->pipeline_format = PixelFormat::kNone;
  c->last_ticket = 0;
  c->plan = {};
  c->width = w;
  c->height = h;
  if (c->slot <= 0) {
    c->status_reason = "slot " + std::to_string(c->slot) + " 未配置模型";
    DescribePlan(*c);
    PublishStats(*c, "passthrough", true);
    return 0;  // no chain: the filter keeps the frame as it is
  }
  if (!c->slot_models.count(c->slot)) {
    c->status_reason = "The selected slot has no configured model";
    c->Log(kLogError, c->status_reason);
    PublishStats(*c, "failed", true);
    return AJI_ERR_CONF;
  }
  FrameDescription frame;
  frame.format = PixelFormat::kNv12;  // refined when the first frame arrives
  frame.matrix = ColorMatrix::kBt709;
  frame.range = ColorRange::kLimited;
  frame.coded_width = static_cast<uint32_t>(w);
  frame.coded_height = static_cast<uint32_t>(h);
  frame.visible_width = static_cast<uint32_t>(w);
  frame.visible_height = static_cast<uint32_t>(h);
  const std::string validation = ValidateFrameDescription(frame);
  if (!validation.empty()) {
    // Outside the verified 2x budget: keep normal playback.
    c->status_reason = validation;
    c->Log(kLogInfo, "Shim passes through: " + validation);
    DescribePlan(*c);
    PublishStats(*c, "passthrough", true);
    return 0;
  }
  c->width = w;
  c->height = h;
  c->fps = std::isfinite(fps) && fps > 0.0 ? fps : 0.0;
  if (c->trt_enabled && !c->trt_failed) {
    if (!c->build || c->build_slot != c->slot || c->build_width != w ||
        c->build_height != h) {
      c->build.reset();  // Cancels/reaps the previous generation's child.
      c->trt_engine.clear();
      c->trt_resources.reset();
      c->build_notified = false;
      c->build_slot = c->slot;
      c->build_width = w;
      c->build_height = h;
      const auto gpu = QueryGpuCapabilities(c->device.Get());
      c->gpu = gpu;
      if (gpu.vendor != 0x10de || gpu.cuda_device < 0) {
        c->trt_failed = true;
        c->backend_reason =
            gpu.vendor != 0x10de
                ? "AI 实时超分需要 NVIDIA 显卡和已配置的 TensorRT"
                : "NVIDIA 驱动或播放设备不支持 TensorRT：" + gpu.cuda_reason;
      } else {
        if (gpu.compute_major * 10 + gpu.compute_minor != 89 ||
            gpu.cuda_driver_version < 13040) {
          c->trt_failed = true;
          c->backend_reason =
              "当前组件仅验证 SM89 显卡，且需要 CUDA 13.4 或更高版本驱动";
        } else if (!std::filesystem::exists(c->trt_dir / L"nvinfer_11.dll") ||
                   !std::filesystem::exists(c->trt_dir / L"trtexec.exe")) {
          c->backend_reason = "尚未安装 TensorRT 组件，请在应用设置中安装";
          c->status_reason = c->backend_reason;
          PublishStats(*c, "resources_missing", true);
          return 0;
        } else {
          const auto plan = MakeFramePlan(frame);
          c->build = std::make_unique<TrtEngineBuild>(
              c->trt_dir, c->engine_cache, c->slot_models[c->slot], gpu,
              plan.model_width, plan.model_height);
        }
      }
    }
    if (c->build) {
      const auto result = c->build->snapshot();
      if (result.phase == TrtEngineBuild::Phase::kPreparing) {
        c->backend_reason =
            result.reason.empty()
                ? "正在准备当前设备的 TensorRT 模型，准备期间正常播放"
                : result.reason;
        c->status_reason = c->backend_reason;
        DescribePlan(*c);
        PublishStats(*c, "preparing", true);
        return 0;  // No active chain; mpv polls aji_poll while copying frames.
      }
      if (result.phase == TrtEngineBuild::Phase::kReady) {
        c->trt_engine = result.engine;
        c->trt_resources = result.resources;
        c->backend_reason.clear();
      } else {
        c->trt_failed = true;
        c->backend_reason = result.reason;
        c->Log(kLogError, "TensorRT 准备失败，保持普通播放：" + result.reason);
      }
    }
  }
  if (c->trt_enabled &&
      (c->trt_failed || !c->trt_resources || c->trt_engine.empty())) {
    c->status_reason = c->backend_reason.empty()
                           ? "AI 实时超分需要先配置 TensorRT"
                           : c->backend_reason;
    c->Log(kLogError, c->status_reason);
    DescribePlan(*c);
    PublishStats(*c, "failed", true);
    return AJI_ERR_ENGINE;
  }
  *out_w = w * 2;
  *out_h = h * 2;
  c->status_reason.clear();
  DescribePlan(*c);
  PublishStats(*c, "configured", true);
  return 1;
} catch (const std::exception& error) {
  return Fail(c, error.what());
} catch (...) {
  return Fail(c, "Unexpected pipeline configuration failure");
}

AJI_EXPORT int aji_infer(aji_ctx* c, const aji_frame* in, const aji_frame* out,
                         void* cu_stream) try {
  (void)cu_stream;
  if (!c || !in || !out || !in->plane[0] || !out->plane[0]) return AJI_ERR;
  std::lock_guard<std::mutex> lock(c->mutex);
  if (c->slot <= 0 || !c->slot_models.count(c->slot)) {
    c->Log(kLogError, "Inference requested without an active slot");
    return AJI_ERR_CONF;
  }
  const PixelFormat format = ToPixelFormat(in->format);
  if (format == PixelFormat::kNone || out->format != in->format) {
    c->status_reason = "不支持的帧格式";
    c->Log(kLogError,
           "Unsupported frame format: " + std::to_string(in->format));
    PublishStats(*c, "failed", true);
    return AJI_ERR_FORMAT;
  }
  if (in->matrix != AJI_MATRIX_BT709 || in->range != AJI_RANGE_LIMITED) {
    c->status_reason = "色彩契约不符（仅 BT.709 limited）";
    c->Log(kLogError, "The shim only verified BT.709 limited-range input");
    PublishStats(*c, "failed", true);
    return AJI_ERR_FORMAT;
  }
  if (in->width != c->width || in->height != c->height ||
      out->width != c->width * 2 || out->height != c->height * 2) {
    c->status_reason = "帧尺寸与配置不一致";
    c->Log(kLogError, "Frame dimensions do not match the configured stream");
    PublishStats(*c, "failed", true);
    return AJI_ERR_SHAPE;
  }
  auto* input_texture = static_cast<ID3D11Texture2D*>(in->plane[0]);
  auto* output_texture = static_cast<ID3D11Texture2D*>(out->plane[0]);
  if (!CreatePlaneViews(*c, input_texture, format)) {
    c->Log(kLogError, "Cannot create views for the input frame planes");
    return AJI_ERR;
  }
  if (!c->pipeline || c->pipeline_format != format) {
    FramePipeline::Config config;
    config.runtime_directory = c->runtime_dir;
    config.model = c->slot_models[c->slot];
    config.trt_engine = c->trt_engine;
    config.trt_resources = c->trt_resources;
    config.require_tensorrt = c->trt_enabled;
    if (config.model.is_relative())
      config.model = c->model_dir / config.model.filename();
    config.frame.format = format;
    config.frame.matrix = ColorMatrix::kBt709;
    config.frame.range = ColorRange::kLimited;
    config.frame.coded_width = static_cast<uint32_t>(c->width);
    config.frame.coded_height = static_cast<uint32_t>(c->height);
    config.frame.visible_width = static_cast<uint32_t>(c->width);
    config.frame.visible_height = static_cast<uint32_t>(c->height);
    config.frame.chroma_x_offset =
        in->siting == AJI_SITING_CENTER ? 0.5f : 0.0f;
    config.frame.chroma_y_offset = in->siting == AJI_SITING_LEFT ? 0.5f : 0.0f;
    std::string reason;
    c->pipeline = FramePipeline::Create(c->device.Get(), config, &reason);
    if (!c->pipeline && c->trt_enabled) {
      c->trt_failed = true;
      c->backend_reason = reason;
      c->trt_engine.clear();
      c->trt_resources.reset();
      c->Log(kLogError, "TensorRT 推理不可用，保持普通播放：" + reason);
    }
    if (!c->pipeline) {
      c->status_reason = reason;
      c->Log(kLogError, "Cannot prepare the shim pipeline: " + reason);
      PublishStats(*c, "failed", true);
      return AJI_ERR_ENGINE;
    }
    c->pipeline_format = format;
    c->pipeline->ConfigureFrameRate(c->fps);
    c->plan = c->pipeline->plan();
    c->color = MakeColorConversion(config.frame);
    DescribePlan(*c);
  }
  try {
    c->last_ticket = c->pipeline->Submit(c->context.Get(), c->luma_view.Get(),
                                         c->chroma_view.Get(), output_texture);
  } catch (const std::exception& error) {
    ++c->frames_failed;
    c->status_reason = error.what();
    c->Log(kLogError, std::string("Inference failed: ") + error.what());
    PublishStats(*c, "failed", true);
    return AJI_ERR;
  }
  ++c->frames_inferred;
  if (c->pipeline->fallback_recommended()) {
    c->status_reason = "AnimeJaNai exceeded the frame budget for three windows";
    c->Log(kLogError, c->status_reason);
    PublishStats(*c, "failed", true);
    return AJI_ERR_ENGINE;
  }
  c->status_reason.clear();
  const FramePipeline::Timing timing = c->pipeline->last_timing();
  if (timing.gpu_measured) c->last_gpu_ms = timing.gpu_total_ms;
  PublishStats(*c, "active", false);
  return AJI_OK;
} catch (const std::exception& error) {
  return Fail(c, error.what());
} catch (...) {
  return Fail(c, "Unexpected inference failure");
}

AJI_EXPORT uint64_t aji_flush(aji_ctx* c, void* cu_stream) try {
  (void)cu_stream;
  if (!c) return 0;
  std::lock_guard<std::mutex> lock(c->mutex);
  return c->last_ticket;
} catch (...) {
  return 0;
}

AJI_EXPORT int aji_done(aji_ctx* c, uint64_t ticket) try {
  if (!c || !ticket) return 1;
  std::lock_guard<std::mutex> lock(c->mutex);
  if (!c->pipeline) return 1;
  return c->pipeline->Complete(ticket) ? 1 : 0;
} catch (const std::exception& error) {
  return Fail(c, error.what());
} catch (...) {
  return Fail(c, "Unexpected completion failure");
}

AJI_EXPORT int aji_wait(aji_ctx* c, uint64_t ticket) try {
  if (!c || !ticket) return AJI_OK;
  std::lock_guard<std::mutex> lock(c->mutex);
  if (!c->pipeline) return AJI_OK;
  c->pipeline->Wait(ticket, 30000);
  return AJI_OK;
} catch (const std::exception& error) {
  return Fail(c, error.what());
} catch (...) {
  return Fail(c, "Unexpected wait failure");
}

AJI_EXPORT const char* aji_current_log(aji_ctx* c) try {
  if (!c) return "";
  std::lock_guard<std::mutex> lock(c->mutex);
  return c->log_text.c_str();
} catch (...) {
  return "";
}

AJI_EXPORT int aji_scale_factor(aji_ctx* c) try {
  if (!c) return 0;
  std::lock_guard<std::mutex> lock(c->mutex);
  return c->pipeline ? 2 : 0;
} catch (...) {
  return 0;
}

AJI_EXPORT int aji_rife_factor(aji_ctx* c, int* num, int* den) {
  (void)c;
  if (num) *num = 1;
  if (den) *den = 1;
  return 0;  // the first release ships no interpolation
}

AJI_EXPORT int aji_rife_before_upscale(aji_ctx* c) {
  (void)c;
  return 0;
}

AJI_EXPORT int aji_pre_resize(aji_ctx* c, int* work_w, int* work_h) {
  (void)c;
  if (work_w) *work_w = 0;
  if (work_h) *work_h = 0;
  return 0;
}

AJI_EXPORT int aji_resize(aji_ctx* c, const aji_frame* in, const aji_frame* out,
                          void* cu_stream) {
  (void)c;
  (void)in;
  (void)out;
  (void)cu_stream;
  return AJI_ERR;
}

AJI_EXPORT int aji_poll(aji_ctx* c) try {
  if (!c) return 0;
  std::lock_guard<std::mutex> lock(c->mutex);
  if (!c->build || c->build_notified) return 0;
  const auto progress = c->build->snapshot();
  if (progress.phase == TrtEngineBuild::Phase::kPreparing) {
    c->status_reason = progress.reason;
    PublishStats(*c, "preparing", false);
    return 0;
  }
  c->build_notified = true;
  // Reconfigure on both success and failure; failure restores ordinary playback.
  return 1;
} catch (...) { return 0; }

AJI_EXPORT int aji_infer_rife(aji_ctx* c, const aji_frame* a,
                              const aji_frame* b, double t,
                              const aji_frame* out, void* cu_stream) {
  (void)c;
  (void)a;
  (void)b;
  (void)t;
  (void)out;
  (void)cu_stream;
  return AJI_ERR;
}

AJI_EXPORT const char* aji_last_error(aji_ctx* c) try {
  if (!c) return "";
  std::lock_guard<std::mutex> lock(c->mutex);
  return c->last_error.c_str();
} catch (...) {
  return "";
}

AJI_EXPORT void aji_destroy(aji_ctx** c) {
  if (!c || !*c) return;
  delete *c;
  *c = nullptr;
}

}  // extern "C"
