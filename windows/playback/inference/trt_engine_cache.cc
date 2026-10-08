// Copyright (c) BangumiToday contributors. Licensed under the project MIT.
#include "trt_engine_cache.h"

#include <Windows.h>

#include <algorithm>
#include <chrono>
#include <fstream>
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
                     uint32_t height) {
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
         << LockedAsset::Sha256(model) << '\n';
  return result.str();
}

void RunBuilder(const TrtResources& resources,
                const std::filesystem::path& model,
                const std::filesystem::path& output,
                const std::filesystem::path& log_path,
                const GpuCapabilities& gpu, uint32_t width, uint32_t height,
                const std::atomic<bool>& cancel) {
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
           L"--outputIOFormats=chw"})
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
  Handle log(CreateFileW(log_path.c_str(), GENERIC_WRITE, FILE_SHARE_READ,
                         &security, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL,
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
  for (;;) {
    const DWORD wait = WaitForSingleObject(process.hProcess, 100);
    if (wait == WAIT_OBJECT_0) break;
    if (cancel || Clock::now() >= deadline || wait == WAIT_FAILED) {
      TerminateJobObject(job.value, 1);
      WaitForSingleObject(process.hProcess, 5000);
      throw std::runtime_error(
          cancel ? "TensorRT preparation cancelled"
                 : "TensorRT builder timeout or wait failure");
    }
    // Bound diagnostics so a failed tool cannot fill the cache volume.
    LARGE_INTEGER length{};
    if (GetFileSizeEx(log.value, &length) &&
        length.QuadPart > 32 * 1024 * 1024) {
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
           const std::filesystem::path& active_log) {
  std::vector<std::filesystem::directory_entry> engines;
  std::vector<std::filesystem::directory_entry> logs;
  uintmax_t bytes = 0;
  uintmax_t log_bytes = 0;
  for (const auto& item : std::filesystem::directory_iterator(directory)) {
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
            [](const auto& left, const auto& right) {
              const auto usage = [](const auto& item) {
                const auto stamp =
                    std::filesystem::path(item.path().wstring() + L".used");
                return std::filesystem::exists(stamp)
                           ? std::filesystem::last_write_time(stamp)
                           : item.last_write_time();
              };
              return usage(left) < usage(right);
            });
  std::sort(logs.begin(), logs.end(), [](const auto& left, const auto& right) {
    return left.last_write_time() < right.last_write_time();
  });
  for (const auto& item : logs) {
    if (log_bytes <= uint64_t{128} * 1024 * 1024) break;
    if (item.path() == active_log) continue;
    const auto size = item.file_size();
    if (DeleteFileW(item.path().c_str())) log_bytes -= size;
  }
  bytes += log_bytes;
  for (const auto& item : engines) {
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
    const std::filesystem::path& root, const GpuCapabilities& gpu) {
  Check(gpu.cuda_device >= 0 && gpu.cuda_reason.empty(),
        gpu.cuda_reason.c_str());
  const int sm = gpu.compute_major * 10 + gpu.compute_minor;
  Check(sm == detail::kSupportedSm,
        "TensorRT architecture is not in the verified lock");
  Check(gpu.cuda_driver_version >= detail::kMinimumDriver,
        "NVIDIA driver is too old for the pinned TensorRT/CUDA combination");
  auto result = std::make_shared<TrtResources>();
  result->sm = sm;
  result->directory = std::filesystem::absolute(root).lexically_normal();
  for (const auto& file : detail::kTrtAssets) {
    const auto path = result->directory / file.name;
    const auto attributes = GetFileAttributesW(path.c_str());
    Check(attributes != INVALID_FILE_ATTRIBUTES &&
              !(attributes &
                (FILE_ATTRIBUTE_DIRECTORY | FILE_ATTRIBUTE_REPARSE_POINT)),
          "TensorRT resource is missing or is a link");
    result->leases.push_back(LockedAsset::File(path, file.bytes, file.sha256));
  }
  return result;
}

TrtEngineBuild::TrtEngineBuild(std::filesystem::path runtime,
                               std::filesystem::path cache,
                               std::filesystem::path model, GpuCapabilities gpu,
                               uint32_t width, uint32_t height) {
  worker_ =
      std::thread([this, runtime = std::move(runtime), cache = std::move(cache),
                   model = std::move(model), gpu, width, height]() {
        Work(runtime, cache, model, gpu, width, height);
      });
}
TrtEngineBuild::~TrtEngineBuild() {
  cancel_ = true;
  if (worker_.joinable()) worker_.join();
}
TrtEngineBuild::Result TrtEngineBuild::snapshot() const {
  std::lock_guard<std::mutex> lock(mutex_);
  return result_;
}
void TrtEngineBuild::Work(const std::filesystem::path& runtime,
                          const std::filesystem::path& cache,
                          const std::filesystem::path& model,
                          const GpuCapabilities& gpu, uint32_t width,
                          uint32_t height) noexcept {
  try {
    const auto progress = [this](const char* reason,
                                 const std::filesystem::path& log = {}) {
      std::lock_guard<std::mutex> lock(mutex_);
      result_.reason = reason;
      if (!log.empty()) result_.log = log;
    };
    progress("正在校验 TensorRT 组件和模型");
    auto resources = TrtResources::Open(runtime, gpu);
    if (cancel_) throw std::runtime_error("TensorRT preparation cancelled");
    auto model_lease = LockedAsset::Model(model);
    const std::string identity = Identity(model, gpu, width, height);
    const std::string key = LockedAsset::HashText(identity);
    std::filesystem::create_directories(cache);
    // A process-wide and cross-process budget of one build per physical GPU.
    const std::wstring mutex_name = L"Local\\BangumiToday.TrtBuild." +
                                    std::to_wstring(gpu.luid.HighPart) + L"." +
                                    std::to_wstring(gpu.luid.LowPart);
    Handle build_lock(CreateMutexW(nullptr, FALSE, mutex_name.c_str()));
    Check(build_lock.value != nullptr, "Cannot create TensorRT build lock");
    progress("等待当前显卡的其他编译任务完成");
    const auto deadline = Clock::now() + std::chrono::minutes(20);
    for (;;) {
      if (cancel_) throw std::runtime_error("TensorRT preparation cancelled");
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
    std::filesystem::path build_log;
    progress("正在检查引擎缓存");
    try {
      valid =
          ReadText(metadata) == identity + LockedAsset::Sha256(engine) + '\n';
      if (valid) {
        TrtSession warm(resources, engine, gpu, width, height);
      }
    } catch (...) {
      valid = false;
    }
    if (!valid) {
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
      build_log = engine.wstring() + L".part-" +
                  std::to_wstring(GetCurrentProcessId()) + L"-" +
                  std::to_wstring(Clock::now().time_since_epoch().count()) +
                  L".log";
      progress("正在编译 TensorRT 引擎", build_log);
      RunBuilder(*resources, model, temporary, build_log, gpu, width, height,
                 cancel_);
      if (cancel_) throw std::runtime_error("TensorRT preparation cancelled");
      progress("正在加载并预热编译结果");
      {
        TrtSession warm(resources, temporary, gpu, width, height);
      }
      if (cancel_) throw std::runtime_error("TensorRT preparation cancelled");
      WriteText(temporary_meta,
                identity + LockedAsset::Sha256(temporary) + '\n');
      Check(MoveFileExW(temporary.c_str(), engine.c_str(),
                        MOVEFILE_REPLACE_EXISTING | MOVEFILE_WRITE_THROUGH) !=
                FALSE,
            "Cannot publish validated TensorRT engine");
      Check(MoveFileExW(temporary_meta.c_str(), metadata.c_str(),
                        MOVEFILE_REPLACE_EXISTING | MOVEFILE_WRITE_THROUGH) !=
                FALSE,
            "Cannot publish TensorRT engine metadata");
    }
    auto engine_lease = std::shared_ptr<LockedAsset>(
        LockedAsset::File(engine, std::filesystem::file_size(engine),
                          LockedAsset::Sha256(engine)));
    // A separate usage stamp can be refreshed while another Player holds a
    // read-only engine lease. In-flight results also keep a lease until taken.
    WriteText(used, key);
    try {
      Prune(cache, engine, build_log);
    } catch (...) {
    }
    std::lock_guard<std::mutex> lock(mutex_);
    result_ = {Phase::kReady, engine, {}, resources, engine_lease, result_.log};
  } catch (const std::exception& error) {
    std::lock_guard<std::mutex> lock(mutex_);
    result_ = {Phase::kFailed, {}, error.what(), {}, {}, result_.log};
    try {
      Prune(cache, {}, result_.log);
    } catch (...) {
    }
  } catch (...) {
    std::lock_guard<std::mutex> lock(mutex_);
    result_ = {
        Phase::kFailed, {}, "Unexpected TensorRT preparation failure", {}, {},
        result_.log};
    try {
      Prune(cache, {}, result_.log);
    } catch (...) {
    }
  }
}
}  // namespace bangumi::inference
