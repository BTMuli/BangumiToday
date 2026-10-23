// Copyright (c) BangumiToday contributors. Licensed under the project MIT.
#include "trt_engine_cache.h"

#include <Windows.h>

#include <algorithm>
#include <chrono>
#include <fstream>
#include <iomanip>
#include <sstream>
#include <stdexcept>

#include "cuda_api.h"
#include "trt_assets_data.h"
#include "trt_session.h"

namespace bangumi::inference {
namespace {
using Clock = std::chrono::steady_clock;
struct Handle final {
  HANDLE value = nullptr;
  explicit Handle(HANDLE handle = nullptr) : value(handle) {}
  ~Handle() {
    if (value && value != INVALID_HANDLE_VALUE) CloseHandle(value);
  }
  Handle(const Handle&) = delete;
  Handle& operator=(const Handle&) = delete;
};

void Check(bool success, const char* operation) {
  if (!success) throw std::runtime_error(operation);
}
void AppendBuildLog(const std::filesystem::path& path,
                    const std::string& message) {
  if (path.empty()) return;
  SYSTEMTIME time{};
  GetLocalTime(&time);
  std::ostringstream line;
  line << '[' << std::setfill('0') << std::setw(2) << time.wHour << ':'
       << std::setw(2) << time.wMinute << ':' << std::setw(2) << time.wSecond
       << "] [BangumiToday] " << message << "\r\n";
  const auto text = line.str();
  Handle file(CreateFileW(path.c_str(), FILE_APPEND_DATA,
      FILE_SHARE_READ | FILE_SHARE_WRITE, nullptr, OPEN_ALWAYS,
      FILE_ATTRIBUTE_NORMAL, nullptr));
  if (file.value == INVALID_HANDLE_VALUE) return;
  DWORD written = 0;
  WriteFile(file.value, text.data(), static_cast<DWORD>(text.size()),
            &written, nullptr);
}
std::wstring Quote(const std::wstring& argument) {
  std::wstring result = L"\"";
  size_t slashes = 0;
  for (wchar_t character : argument) {
    if (character == L'\\') {
      ++slashes;
      continue;
    }
    result.append(slashes * (character == L'\"' ? 2 : 1), L'\\');
    if (character == L'\"') result += L'\\';
    result += character;
    slashes = 0;
  }
  result.append(slashes * 2, L'\\');
  return result + L'\"';
}

std::string ReadText(const std::filesystem::path& path) {
  std::ifstream file(path, std::ios::binary);
  if (!file) return {};
  Check(std::filesystem::file_size(path) <= 4096, "Oversized engine metadata");
  return {(std::istreambuf_iterator<char>(file)),
          std::istreambuf_iterator<char>()};
}
void WriteText(const std::filesystem::path& path, const std::string& text) {
  std::ofstream file(path, std::ios::binary | std::ios::trunc);
  file << text;
  file.flush();
  Check(file.good(), "Cannot write engine metadata");
}

std::string Identity(const std::filesystem::path& model,
                     const GpuCapabilities& gpu, uint32_t width,
                     uint32_t height, const AssetReadProgress& progress) {
  CudaApi cuda;
  CUuuid uuid{};
  CudaApi::Check(cuda.cuDeviceGetUuid(&uuid, gpu.cuda_device),
                 "CUDA device UUID");
  std::ostringstream result;
  result << "bridge=8;trt-frame=1;trt=" << detail::kTrtVersion
         << ";cuda=" << detail::kCudaVersion
         << ";driver=" << gpu.cuda_driver_version
         << ";sm=" << gpu.compute_major * 10 + gpu.compute_minor
         << ";luid=" << gpu.luid.HighPart << ':' << gpu.luid.LowPart
         << ";uuid=";
  constexpr char alphabet[] = "0123456789abcdef";
  for (unsigned char byte : uuid.bytes)
    result << alphabet[byte >> 4] << alphabet[byte & 15];
  result << ";shape=1x3x" << height << 'x' << width
         << ";type=fp16;format=linear;opt=3;aux=0;workspace=1024MiB;model="
         << LockedAsset::Sha256(model, progress) << '\n';
  return result.str();
}

void RunBuilder(const TrtResources& resources,
                const std::filesystem::path& model,
                const std::filesystem::path& output,
                const std::filesystem::path& log_path,
                const GpuCapabilities& gpu, uint32_t width, uint32_t height,
                const std::function<void()>& checkpoint, HANDLE cancel_event) {
  checkpoint();
  const auto executable = resources.directory / L"trtexec.exe";
  const std::wstring shape =
      L"input:1x3x" + std::to_wstring(height) + L"x" + std::to_wstring(width);
  std::wstring command = Quote(executable.wstring());
  for (const auto& argument : std::vector<std::wstring>{
           L"--onnx=" + model.wstring(), L"--saveEngine=" + output.wstring(),
           L"--minShapes=" + shape, L"--optShapes=" + shape,
           L"--maxShapes=" + shape,
           L"--device=" + std::to_wstring(gpu.cuda_device), L"--skipInference",
           L"--builderOptimizationLevel=3", L"--maxAuxStreams=0",
           L"--memPoolSize=workspace:1024", L"--inputIOFormats=chw",
           L"--outputIOFormats=chw", L"--verbose"})
    command += L" " + Quote(argument);
  // The FP16 model supplies the types. TensorRT 11 removed --fp16.
  std::vector<wchar_t> writable(command.begin(), command.end());
  writable.push_back(0);
  wchar_t system[MAX_PATH]{};
  Check(GetSystemDirectoryW(system, MAX_PATH) != 0, "Cannot locate System32");
  const std::filesystem::path system_dir(system);
  // Do not inherit user PATH, CUDA_PATH, plugin paths or other inference
  // configuration. The exact resources are self-contained next to trtexec.
  const std::vector<std::wstring> environment{
      L"PATH=" + resources.directory.wstring() + L";" + system_dir.wstring(),
      L"SystemRoot=" + system_dir.parent_path().wstring(),
      L"TEMP=" + output.parent_path().wstring(),
      L"TMP=" + output.parent_path().wstring()};
  std::vector<wchar_t> block;
  for (const auto& entry : environment) {
    block.insert(block.end(), entry.begin(), entry.end());
    block.push_back(0);
  }
  block.push_back(0);
  SECURITY_ATTRIBUTES security{sizeof(SECURITY_ATTRIBUTES), nullptr, TRUE};
  Handle log(CreateFileW(log_path.c_str(), FILE_APPEND_DATA,
                         FILE_SHARE_READ | FILE_SHARE_WRITE,
                         &security, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL,
                         nullptr));
  Check(log.value != INVALID_HANDLE_VALUE, "Cannot open TensorRT build log");
  Handle null_input(CreateFileW(L"NUL", GENERIC_READ,
                                FILE_SHARE_READ | FILE_SHARE_WRITE, &security,
                                OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, nullptr));
  // Restrict inherited handles to these two: no media, database or application
  // handles may accidentally keep the Player alive in a long-running build.
  SIZE_T attribute_bytes = 0;
  InitializeProcThreadAttributeList(nullptr, 1, 0, &attribute_bytes);
  std::vector<unsigned char> attributes(attribute_bytes);
  auto* list =
      reinterpret_cast<LPPROC_THREAD_ATTRIBUTE_LIST>(attributes.data());
  Check(
      InitializeProcThreadAttributeList(list, 1, 0, &attribute_bytes) != FALSE,
      "Cannot initialize builder handle list");
  struct AttributeScope {
    LPPROC_THREAD_ATTRIBUTE_LIST list;
    ~AttributeScope() { DeleteProcThreadAttributeList(list); }
  } attribute_scope{list};
  HANDLE handles[]{log.value, null_input.value};
  Check(UpdateProcThreadAttribute(list, 0, PROC_THREAD_ATTRIBUTE_HANDLE_LIST,
                                  handles, sizeof(handles), nullptr,
                                  nullptr) != FALSE,
        "Cannot restrict builder inherited handles");
  STARTUPINFOEXW startup{};
  startup.StartupInfo.cb = sizeof(startup);
  startup.StartupInfo.dwFlags = STARTF_USESTDHANDLES;
  startup.StartupInfo.hStdOutput = startup.StartupInfo.hStdError = log.value;
  startup.StartupInfo.hStdInput = null_input.value;
  startup.lpAttributeList = list;
  Handle job(CreateJobObjectW(nullptr, nullptr));
  Check(job.value != nullptr, "Cannot create builder job");
  JOBOBJECT_EXTENDED_LIMIT_INFORMATION limits{};
  limits.BasicLimitInformation.LimitFlags = JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE;
  Check(SetInformationJobObject(job.value, JobObjectExtendedLimitInformation,
                                &limits, sizeof(limits)) != FALSE,
        "Cannot configure builder job");
  checkpoint();
  PROCESS_INFORMATION process{};
  Check(CreateProcessW(
            executable.c_str(), writable.data(), nullptr, nullptr, TRUE,
            CREATE_NO_WINDOW | CREATE_SUSPENDED | CREATE_UNICODE_ENVIRONMENT |
                EXTENDED_STARTUPINFO_PRESENT,
            block.data(), resources.directory.c_str(), &startup.StartupInfo,
            &process) != FALSE,
        "Cannot launch pinned trtexec");
  Handle process_handle(process.hProcess);
  Handle thread_handle(process.hThread);
  if (!AssignProcessToJobObject(job.value, process.hProcess)) {
    TerminateProcess(process.hProcess, 1);
    WaitForSingleObject(process.hProcess, 5000);
    throw std::runtime_error("Cannot attach builder to cancellation job");
  }
  Check(ResumeThread(process.hThread) != static_cast<DWORD>(-1),
        "Cannot resume builder");
  const auto deadline = Clock::now() + std::chrono::minutes(15);
  const auto started = Clock::now();
  auto last_report = started;
  for (;;) {
    HANDLE waiting[]{process.hProcess, cancel_event};
    const DWORD wait = WaitForMultipleObjects(
        cancel_event ? 2 : 1, waiting, FALSE, 100);
    if (wait == WAIT_OBJECT_0) break;
    try {
      checkpoint();
      Check(Clock::now() < deadline && wait != WAIT_FAILED,
            "TensorRT builder timeout or wait failure");
    } catch (...) {
      TerminateJobObject(job.value, 1);
      WaitForSingleObject(process.hProcess, 5000);
      throw;
    }
    if (Clock::now() - last_report >= std::chrono::seconds(5)) {
      last_report = Clock::now();
      AppendBuildLog(log_path, "编译器仍在运行（网络优化 / 算子策略搜索可能耗时较长）· 已耗时 " +
          std::to_string(std::chrono::duration_cast<std::chrono::seconds>(
              last_report - started).count()) + " 秒");
    }
    // Bound diagnostics so a failed tool cannot fill the cache volume.
    LARGE_INTEGER length{};
    if (GetFileSizeEx(log.value, &length) &&
        length.QuadPart > 128 * 1024 * 1024) {
      TerminateJobObject(job.value, 1);
      WaitForSingleObject(process.hProcess, 5000);
      throw std::runtime_error("TensorRT builder log limit exceeded");
    }
  }
  DWORD exit_code = 1;
  Check(GetExitCodeProcess(process.hProcess, &exit_code) && exit_code == 0,
        "TensorRT engine build failed; see the cache build log");
}

void Prune(const std::filesystem::path& directory,
           const std::filesystem::path& active,
           const std::filesystem::path& active_log,
           const std::function<void()>& checkpoint) {
  std::vector<std::filesystem::directory_entry> engines;
  std::vector<std::filesystem::directory_entry> logs;
  uintmax_t bytes = 0;
  uintmax_t log_bytes = 0;
  for (const auto& item : std::filesystem::directory_iterator(directory)) {
    checkpoint();
    const auto filename = item.path().filename().wstring();
    if (item.is_regular_file() && !item.is_symlink() && filename.size() > 80 &&
        filename.substr(0, 64).find_first_not_of(L"0123456789abcdef") ==
            std::wstring::npos &&
        filename.substr(64, 13) == L".engine.part-" &&
        item.path().extension() == L".log") {
      logs.push_back(item);
      log_bytes += item.file_size();
      continue;
    }
    const auto name = item.path().stem().wstring();
    if (!item.is_regular_file() || item.is_symlink() || name.size() != 64 ||
        item.path().extension() != L".engine" ||
        name.find_first_not_of(L"0123456789abcdef") != std::wstring::npos)
      continue;
    engines.push_back(item);
    bytes += item.file_size();
  }
  std::sort(engines.begin(), engines.end(),
            [&](const auto& left, const auto& right) {
              checkpoint();
              const auto usage = [](const auto& item) {
                const auto stamp =
                    std::filesystem::path(item.path().wstring() + L".used");
                return std::filesystem::exists(stamp)
                           ? std::filesystem::last_write_time(stamp)
                           : item.last_write_time();
              };
              return usage(left) < usage(right);
            });
  std::sort(logs.begin(), logs.end(), [&](const auto& left, const auto& right) {
    checkpoint();
    return left.last_write_time() < right.last_write_time();
  });
  for (const auto& item : logs) {
    checkpoint();
    if (log_bytes <= uint64_t{128} * 1024 * 1024) break;
    if (item.path() == active_log) continue;
    const auto size = item.file_size();
    if (DeleteFileW(item.path().c_str())) log_bytes -= size;
  }
  bytes += log_bytes;
  for (const auto& item : engines) {
    checkpoint();
    if (bytes <= uint64_t{4} * 1024 * 1024 * 1024) break;
    if (item.path() == active) continue;
    const auto size = item.file_size();
    // Engine sessions keep a no-delete-sharing lease. Windows refuses removal
    // while any Player uses this entry; failed removals are left alone.
    if (DeleteFileW(item.path().c_str())) {
      bytes -= size;
      DeleteFileW((item.path().wstring() + L".meta").c_str());
      DeleteFileW((item.path().wstring() + L".used").c_str());
    }
  }
}
}  // namespace

std::shared_ptr<TrtResources> TrtResources::Open(
    const std::filesystem::path& root, const GpuCapabilities& gpu,
    const std::function<void(const std::filesystem::path&, uint64_t, uint64_t)>&
        progress) {
  Check(gpu.cuda_device >= 0 && gpu.cuda_reason.empty(),
        gpu.cuda_reason.c_str());
  const int sm = gpu.compute_major * 10 + gpu.compute_minor;
  Check(detail::SupportsSm(sm),
        "TensorRT architecture is not in the pinned lock");
  Check(gpu.cuda_driver_version >= detail::kMinimumDriver,
        "NVIDIA driver is too old for the pinned TensorRT/CUDA combination");
  auto result = std::make_shared<TrtResources>();
  result->sm = sm;
  result->directory = std::filesystem::absolute(root).lexically_normal();
  for (const auto& file : detail::kTrtAssets) {
    if (file.sm != 0 && file.sm != sm) continue;
    const auto path = result->directory / file.name;
    const auto attributes = GetFileAttributesW(path.c_str());
    Check(attributes != INVALID_FILE_ATTRIBUTES &&
              !(attributes &
                (FILE_ATTRIBUTE_DIRECTORY | FILE_ATTRIBUTE_REPARSE_POINT)),
          "TensorRT resource is missing or is a link");
    result->leases.push_back(LockedAsset::File(path, file.bytes, file.sha256,
        [&](uint64_t read) {
          if (progress) progress(path, read, file.bytes);
        }));
  }
  return result;
}

TrtEngineBuild::TrtEngineBuild(std::filesystem::path runtime,
                               std::filesystem::path cache,
                               std::filesystem::path model, GpuCapabilities gpu,
                               uint32_t width, uint32_t height,
                               const std::wstring& cancel_event) {
  if (!cancel_event.empty()) {
    cancel_event_ = CreateEventW(nullptr, TRUE, FALSE, cancel_event.c_str());
    Check(cancel_event_ != nullptr, "Cannot open TensorRT cancellation event");
  }
  try {
    worker_ =
        std::thread([this, runtime = std::move(runtime), cache = std::move(cache),
                     model = std::move(model), gpu, width, height]() {
          Work(runtime, cache, model, gpu, width, height);
        });
  } catch (...) {
    if (cancel_event_) CloseHandle(cancel_event_);
    throw;
  }
}
TrtEngineBuild::~TrtEngineBuild() {
  cancel_ = true;
  if (worker_.joinable()) worker_.join();
  if (cancel_event_) CloseHandle(cancel_event_);
}
bool TrtEngineBuild::IsCancelled() const {
  return cancel_ || (cancel_event_ &&
      WaitForSingleObject(cancel_event_, 0) == WAIT_OBJECT_0);
}
void TrtEngineBuild::CheckCancelled() const {
  if (IsCancelled()) throw std::runtime_error("TensorRT 编译已取消");
}
TrtEngineBuild::Result TrtEngineBuild::snapshot() const {
  std::lock_guard<std::mutex> lock(mutex_);
  auto result = result_;
  if (result.phase == Phase::kPreparing && !result.reason.empty()) {
    const auto now = Clock::now();
    result.reason += " · 本阶段 " + std::to_string(
        std::chrono::duration_cast<std::chrono::seconds>(
            now - stage_started_).count()) + " 秒 · 累计 " + std::to_string(
        std::chrono::duration_cast<std::chrono::seconds>(
            now - started_).count()) + " 秒";
  }
  return result;
}
void TrtEngineBuild::Work(const std::filesystem::path& runtime,
                          const std::filesystem::path& cache,
                          const std::filesystem::path& model,
                          const GpuCapabilities& gpu, uint32_t width,
                          uint32_t height) noexcept {
  std::filesystem::path build_log;
  try {
    CheckCancelled();
    std::filesystem::create_directories(cache);
    // Diagnostics start before the large runtime files are hashed. The name
    // follows the same bounded cache-log contract as the compiler's output.
    const auto log_key = LockedAsset::HashText(
        model.u8string() + ";" + std::to_string(width) + "x" +
        std::to_string(height));
    build_log = cache / (log_key + ".engine.part-" +
        std::to_string(GetCurrentProcessId()) + "-" +
        std::to_string(Clock::now().time_since_epoch().count()) + ".log");
    {
      std::lock_guard<std::mutex> lock(mutex_);
      result_.log = build_log;
    }
    const auto progress = [&](const std::string& reason) {
      CheckCancelled();
      const auto now = Clock::now();
      std::lock_guard<std::mutex> lock(mutex_);
      if (!result_.reason.empty()) {
        AppendBuildLog(build_log, result_.reason + " · 耗时 " +
            std::to_string(std::chrono::duration_cast<
                std::chrono::milliseconds>(now - stage_started_).count()) +
            " 毫秒");
      }
      result_.reason = reason;
      stage_started_ = now;
      AppendBuildLog(build_log, reason);
    };
    const AssetReadProgress checkpoint = [this](uint64_t) {
      CheckCancelled();
    };
    auto last_asset_report = Clock::now();
    auto resources = TrtResources::Open(runtime, gpu,
        [&](const std::filesystem::path& file, uint64_t read, uint64_t total) {
          CheckCancelled();
          const auto now = Clock::now();
          if (read != 0 && read != total && now - last_asset_report <
                  std::chrono::seconds(1)) return;
          const auto reason = "正在校验组件 " + file.filename().u8string();
          if (read == 0) progress(reason);
          if (read == total || now - last_asset_report >=
                                   std::chrono::seconds(1)) {
            last_asset_report = now;
            const auto detail = reason + " · " +
                std::to_string(read / 1048576) + " / " +
                std::to_string(total / 1048576) + " MiB";
            {
              std::lock_guard<std::mutex> lock(mutex_);
              result_.reason = detail;
            }
            AppendBuildLog(build_log, detail);
          }
        });
    progress("正在校验模型 " + model.filename().u8string());
    auto model_lease = LockedAsset::Model(model, checkpoint);
    progress("正在生成显卡、模型和尺寸的缓存身份");
    const std::string identity = Identity(model, gpu, width, height, checkpoint);
    const std::string key = LockedAsset::HashText(identity);
    // A process-wide and cross-process budget of one build per physical GPU.
    const std::wstring mutex_name = L"Local\\BangumiToday.TrtBuild." +
                                    std::to_wstring(gpu.luid.HighPart) + L"." +
                                    std::to_wstring(gpu.luid.LowPart);
    Handle build_lock(CreateMutexW(nullptr, FALSE, mutex_name.c_str()));
    Check(build_lock.value != nullptr, "Cannot create TensorRT build lock");
    progress("等待当前显卡的其他编译任务完成");
    const auto deadline = Clock::now() + std::chrono::minutes(20);
    for (;;) {
      CheckCancelled();
      const auto wait = WaitForSingleObject(build_lock.value, 100);
      if (wait == WAIT_OBJECT_0 || wait == WAIT_ABANDONED) break;
      Check(wait == WAIT_TIMEOUT && Clock::now() < deadline,
            "TensorRT build lock timed out");
    }
    struct MutexScope {
      HANDLE handle;
      ~MutexScope() { ReleaseMutex(handle); }
    } scope{build_lock.value};
    const auto engine = cache / (key + ".engine");
    const auto metadata = std::filesystem::path(engine.wstring() + L".meta");
    const auto used = std::filesystem::path(engine.wstring() + L".used");
    bool valid = false;
    progress("正在检查引擎缓存");
    try {
      valid =
          ReadText(metadata) ==
              identity + LockedAsset::Sha256(engine, checkpoint) + '\n';
      if (valid) {
        progress("命中缓存，正在加载并预热已有引擎");
        TrtSession warm(resources, engine, gpu, width, height,
                       [this] { CheckCancelled(); }, progress);
      }
    } catch (...) {
      CheckCancelled();
      AppendBuildLog(build_log, "引擎缓存不可用，需要重新编译");
      valid = false;
    }
    if (!valid) {
      {
        std::lock_guard<std::mutex> lock(mutex_);
        result_.build_required = true;
      }
      const std::filesystem::path temporary(engine.wstring() + L".part");
      const std::filesystem::path temporary_meta(metadata.wstring() + L".part");
      struct Cleanup {
        std::filesystem::path file, meta;
        ~Cleanup() {
          DeleteFileW(file.c_str());
          DeleteFileW(meta.c_str());
        }
      } cleanup{temporary, temporary_meta};
      DeleteFileW(temporary.c_str());
      progress("正在编译 TensorRT 引擎（网络优化 / 算子策略搜索）");
      RunBuilder(*resources, model, temporary, build_log, gpu, width, height,
                 [this] { CheckCancelled(); }, cancel_event_);
      CheckCancelled();
      progress("正在加载并预热编译结果");
      {
        TrtSession warm(resources, temporary, gpu, width, height,
                       [this] { CheckCancelled(); }, progress);
      }
      progress("正在校验编译结果并写入缓存元数据");
      WriteText(temporary_meta,
                identity + LockedAsset::Sha256(temporary, checkpoint) + '\n');
      progress("正在发布校验通过的引擎缓存");
      Check(MoveFileExW(temporary.c_str(), engine.c_str(),
                        MOVEFILE_REPLACE_EXISTING | MOVEFILE_WRITE_THROUGH) !=
                FALSE,
            "Cannot publish validated TensorRT engine");
      Check(MoveFileExW(temporary_meta.c_str(), metadata.c_str(),
                        MOVEFILE_REPLACE_EXISTING | MOVEFILE_WRITE_THROUGH) !=
                FALSE,
            "Cannot publish TensorRT engine metadata");
    }
    progress("正在锁定引擎缓存");
    auto engine_lease = std::shared_ptr<LockedAsset>(
        LockedAsset::File(engine, std::filesystem::file_size(engine),
                          LockedAsset::Sha256(engine, checkpoint), checkpoint));
    // A separate usage stamp can be refreshed while another Player holds a
    // read-only engine lease. In-flight results also keep a lease until taken.
    WriteText(used, key);
    progress("正在清理旧引擎与编译日志");
    try {
      Prune(cache, engine, build_log, [this] { CheckCancelled(); });
    } catch (...) {
    }
    progress("TensorRT 引擎已就绪");
    AppendBuildLog(build_log, "准备完成 · 累计 " + std::to_string(
        std::chrono::duration_cast<std::chrono::milliseconds>(
            Clock::now() - started_).count()) + " 毫秒");
    std::lock_guard<std::mutex> lock(mutex_);
    result_ = {Phase::kReady, engine, {}, resources, engine_lease, result_.log,
               result_.build_required};
  } catch (const std::exception& error) {
    AppendBuildLog(build_log, std::string(error.what()) + " · 累计 " +
        std::to_string(std::chrono::duration_cast<std::chrono::milliseconds>(
            Clock::now() - started_).count()) + " 毫秒");
    {
      std::lock_guard<std::mutex> lock(mutex_);
      result_ = {Phase::kFailed, {}, error.what(), {}, {}, result_.log,
                 result_.build_required};
    }
    // Cancellation must not spend time pruning a directory before it joins.
    // Other failures still enforce the diagnostic cache budget, outside the
    // status mutex so polling and cancellation remain available.
    if (!IsCancelled()) {
      try {
        Prune(cache, {}, build_log, [this] { CheckCancelled(); });
      } catch (...) {
      }
    }
  } catch (...) {
    AppendBuildLog(build_log, "Unexpected TensorRT preparation failure");
    std::lock_guard<std::mutex> lock(mutex_);
    result_ = {
        Phase::kFailed, {}, "Unexpected TensorRT preparation failure", {}, {},
        result_.log, result_.build_required};
  }
}
}  // namespace bangumi::inference
