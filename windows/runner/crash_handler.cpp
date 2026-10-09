#include "crash_handler.h"

#include <windows.h>
#include <dbghelp.h>
#include <psapi.h>
#include <shellapi.h>

#include <cerrno>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <exception>
#include <limits>
#include <set>
#include <string>
#include <vector>

#include "playback/native_log.h"

namespace {
wchar_t executable[32768]{};
wchar_t dump_stem[32768]{};
wchar_t dump_file[32768]{};
HANDLE crash_log = INVALID_HANDLE_VALUE;
std::wstring running_file;
LPTOP_LEVEL_EXCEPTION_FILTER previous_filter = nullptr;
volatile LONG handling_crash = 0;
wchar_t crash_command[32768]{};
constexpr DWORD kHelperTimeoutMs = 120000;
constexpr DWORD kTriageTimeoutMs = 15000;
constexpr DWORD kFullTimeoutMs = 90000;
constexpr auto kCommonDumpFlags = static_cast<MINIDUMP_TYPE>(
    MiniDumpWithThreadInfo | MiniDumpWithUnloadedModules |
    MiniDumpWithFullMemoryInfo | MiniDumpWithProcessThreadData |
    MiniDumpWithHandleData | MiniDumpIgnoreInaccessibleMemory);

// This identity is also embedded in each dump so it travels with the file.
const char build_identity[] =
#ifdef FLUTTER_VERSION
    "application_version=" FLUTTER_VERSION
    "\r\n"
#endif
#ifdef BANGUMI_FLUTTER_SDK_VERSION
    "flutter_sdk=" BANGUMI_FLUTTER_SDK_VERSION
    "\r\n"
#endif
#ifdef BANGUMI_FLUTTER_ENGINE_REVISION
    "flutter_engine=" BANGUMI_FLUTTER_ENGINE_REVISION
    "\r\n"
#endif
    "capture_format=2\r\n";

// The normal logger constructs strings. Avoid touching the failing process's
// heap here: open its append handle during startup and use only fixed buffers.
void CrashLog(const char* message) noexcept {
  if (crash_log == INVALID_HANDLE_VALUE) {
    OutputDebugStringA(message);
    return;
  }
  SYSTEMTIME time{};
  GetLocalTime(&time);
  char line[4096]{};
  _snprintf_s(line, sizeof(line), _TRUNCATE,
              "%04u-%02u-%02u %02u:%02u:%02u.%03u [ERROR pid=%lu tid=%lu] "
              "%s\r\n",
              time.wYear, time.wMonth, time.wDay, time.wHour, time.wMinute,
              time.wSecond, time.wMilliseconds, GetCurrentProcessId(),
              GetCurrentThreadId(), message);
  DWORD written = 0;
  if (!WriteFile(crash_log, line, static_cast<DWORD>(strlen(line)), &written,
                 nullptr))
    OutputDebugStringA(message);
  FlushFileBuffers(crash_log);
}

struct DumpBudget {
  ULONGLONG started;
  DWORD timeout_ms;
};

BOOL CALLBACK CheckDumpBudget(void* context, MINIDUMP_CALLBACK_INPUT* input,
                              MINIDUMP_CALLBACK_OUTPUT* output) {
  if (input->CallbackType == CancelCallback) {
    const auto budget = static_cast<const DumpBudget*>(context);
    output->CheckCancel = TRUE;
    output->Cancel = GetTickCount64() - budget->started >= budget->timeout_ms;
  }
  return TRUE;
}

void WriteReport(HANDLE report, const char* message) {
  if (report == INVALID_HANDLE_VALUE) return;
  DWORD written = 0;
  WriteFile(report, message, static_cast<DWORD>(strlen(message)), &written,
            nullptr);
  WriteFile(report, "\r\n", 2, &written, nullptr);
  // Keep completed stages available if the parent has to stop the helper.
  FlushFileBuffers(report);
}

DWORD WriteDump(HANDLE process, DWORD owner,
                MINIDUMP_EXCEPTION_INFORMATION* exception,
                const std::wstring& path, MINIDUMP_TYPE type, DWORD timeout_ms,
                HANDLE report, const char* mode) {
  const auto partial = path + L".partial";
  char message[512]{};
  const auto started = GetTickCount64();
  _snprintf_s(message, sizeof(message), _TRUNCATE,
              "dump_mode=%s flags=0x%08X budget_ms=%lu started", mode,
              static_cast<unsigned>(type), timeout_ms);
  WriteReport(report, message);
  HANDLE file =
      CreateFileW(partial.c_str(), GENERIC_WRITE, FILE_SHARE_READ, nullptr,
                  CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, nullptr);
  DWORD error = ERROR_SUCCESS;
  LARGE_INTEGER size{};
  if (file == INVALID_HANDLE_VALUE) {
    error = GetLastError();
  } else {
    DumpBudget budget{started, timeout_ms};
    MINIDUMP_CALLBACK_INFORMATION callbacks{CheckDumpBudget, &budget};
    MINIDUMP_USER_STREAM stream{};
    stream.Type = CommentStreamA;
    stream.BufferSize = static_cast<ULONG>(sizeof(build_identity));
    stream.Buffer = const_cast<char*>(build_identity);
    MINIDUMP_USER_STREAM_INFORMATION streams{1, &stream};
    if (!MiniDumpWriteDump(process, owner, file, type, exception, &streams,
                           &callbacks)) {
      error =
          GetLastError();  // DbgHelp returns an HRESULT, not just Win32 codes.
    } else if (!GetFileSizeEx(file, &size) || !FlushFileBuffers(file)) {
      error = GetLastError();
    }
    CloseHandle(file);
    if (error == ERROR_SUCCESS &&
        !MoveFileExW(partial.c_str(), path.c_str(), MOVEFILE_WRITE_THROUGH)) {
      error = GetLastError();
    }
    if (error != ERROR_SUCCESS) DeleteFileW(partial.c_str());
  }
  _snprintf_s(message, sizeof(message), _TRUNCATE,
              "dump_mode=%s result=0x%08lX bytes=%llu elapsed_ms=%llu", mode,
              error, static_cast<unsigned long long>(size.QuadPart),
              static_cast<unsigned long long>(GetTickCount64() - started));
  WriteReport(report, message);
  return error;
}

void WriteCaptureDetails(HANDLE report, HANDLE process, DWORD owner,
                         DWORD thread, uintptr_t address) {
  WriteReport(report, build_identity);
  char message[2048]{};
  SYSTEMTIME time{};
  GetSystemTime(&time);
  _snprintf_s(message, sizeof(message), _TRUNCATE,
              "capture_utc=%04u-%02u-%02uT%02u:%02u:%02u.%03uZ "
              "pid=%lu exception_tid=%lu exception_pointers=0x%llX",
              time.wYear, time.wMonth, time.wDay, time.wHour, time.wMinute,
              time.wSecond, time.wMilliseconds, owner, thread,
              static_cast<unsigned long long>(address));
  WriteReport(report, message);
  wchar_t path[32768]{};
  DWORD length = _countof(path);
  if (QueryFullProcessImageNameW(process, 0, path, &length)) {
    char utf8[4096]{};
    WideCharToMultiByte(CP_UTF8, 0, path, -1, utf8, sizeof(utf8), nullptr,
                        nullptr);
    WriteReport(report, utf8);
  }
  PROCESS_MEMORY_COUNTERS_EX memory{};
  memory.cb = sizeof(memory);
  if (K32GetProcessMemoryInfo(
          process, reinterpret_cast<PROCESS_MEMORY_COUNTERS*>(&memory),
          sizeof(memory))) {
    _snprintf_s(message, sizeof(message), _TRUNCATE,
                "private_bytes=%llu working_set_bytes=%llu "
                "peak_working_set_bytes=%llu",
                static_cast<unsigned long long>(memory.PrivateUsage),
                static_cast<unsigned long long>(memory.WorkingSetSize),
                static_cast<unsigned long long>(memory.PeakWorkingSetSize));
    WriteReport(report, message);
  }
  EXCEPTION_POINTERS pointers{};
  EXCEPTION_RECORD record{};
  if (!ReadProcessMemory(process, reinterpret_cast<const void*>(address),
                         &pointers, sizeof(pointers), nullptr) ||
      !ReadProcessMemory(process, pointers.ExceptionRecord, &record,
                         sizeof(record), nullptr)) {
    _snprintf_s(message, sizeof(message), _TRUNCATE,
                "read_exception_failed=0x%08lX", GetLastError());
    WriteReport(report, message);
    return;
  }
  _snprintf_s(message, sizeof(message), _TRUNCATE,
              "exception_code=0x%08lX exception_flags=0x%08lX ip=%p",
              record.ExceptionCode, record.ExceptionFlags,
              record.ExceptionAddress);
  WriteReport(report, message);
  for (DWORD i = 0;
       i < record.NumberParameters && i < EXCEPTION_MAXIMUM_PARAMETERS; ++i) {
    _snprintf_s(
        message, sizeof(message), _TRUNCATE, "exception_parameter[%lu]=0x%llX",
        i, static_cast<unsigned long long>(record.ExceptionInformation[i]));
    WriteReport(report, message);
  }
  if ((record.ExceptionCode == EXCEPTION_ACCESS_VIOLATION ||
       record.ExceptionCode == EXCEPTION_IN_PAGE_ERROR) &&
      record.NumberParameters >= 2) {
    const auto operation = record.ExceptionInformation[0];
    const auto fault =
        reinterpret_cast<const void*>(record.ExceptionInformation[1]);
    _snprintf_s(message, sizeof(message), _TRUNCATE,
                "memory_access=%s fault_address=%p",
                operation == 0   ? "read"
                : operation == 1 ? "write"
                : operation == 8 ? "execute"
                                 : "unknown",
                fault);
    WriteReport(report, message);
    MEMORY_BASIC_INFORMATION region{};
    if (VirtualQueryEx(process, fault, &region, sizeof(region))) {
      _snprintf_s(message, sizeof(message), _TRUNCATE,
                  "fault_region base=%p allocation_base=%p bytes=%llu "
                  "state=0x%08lX protect=0x%08lX type=0x%08lX",
                  region.BaseAddress, region.AllocationBase,
                  static_cast<unsigned long long>(region.RegionSize),
                  region.State, region.Protect, region.Type);
      WriteReport(report, message);
    }
  }
}

bool ParseHelperNumber(const wchar_t* text, unsigned long long maximum,
                       unsigned long long* value) {
  if (*text < L'0' || *text > L'9') return false;
  wchar_t* end = nullptr;
  errno = 0;
  *value = _wcstoui64(text, &end, 10);
  return errno != ERANGE && *end == L'\0' && *value != 0 && *value <= maximum;
}

struct CrashArtifact {
  std::wstring name;
  std::wstring base;
  FILETIME time;
  bool partial;
};

bool ParseLogTimestamp(const std::wstring& timestamp, FILETIME* time) {
  if ((timestamp.size() != 15 && timestamp.size() != 19) ||
      timestamp[8] != L'-' || (timestamp.size() == 19 && timestamp[15] != L'-'))
    return false;
  for (size_t i = 0; i < timestamp.size(); ++i) {
    if (i == 8 || i == 15) continue;
    if (timestamp[i] < L'0' || timestamp[i] > L'9') return false;
  }
  SYSTEMTIME local{};
  local.wYear = static_cast<WORD>(_wtoi(timestamp.substr(0, 4).c_str()));
  local.wMonth = static_cast<WORD>(_wtoi(timestamp.substr(4, 2).c_str()));
  local.wDay = static_cast<WORD>(_wtoi(timestamp.substr(6, 2).c_str()));
  local.wHour = static_cast<WORD>(_wtoi(timestamp.substr(9, 2).c_str()));
  local.wMinute = static_cast<WORD>(_wtoi(timestamp.substr(11, 2).c_str()));
  local.wSecond = static_cast<WORD>(_wtoi(timestamp.substr(13, 2).c_str()));
  if (timestamp.size() == 19)
    local.wMilliseconds =
        static_cast<WORD>(_wtoi(timestamp.substr(16, 3).c_str()));
  SYSTEMTIME utc{};
  return TzSpecificLocalTimeToSystemTime(nullptr, &local, &utc) &&
         SystemTimeToFileTime(&utc, time);
}

bool ParseLogSession(const std::wstring& session, DWORD* owner) {
  const auto separator = session.find_last_of(L'-');
  if (separator != 19) return false;
  unsigned long long value = 0;
  FILETIME time{};
  if (!ParseHelperNumber(session.substr(separator + 1).c_str(), MAXDWORD,
                         &value) ||
      !ParseLogTimestamp(session.substr(0, separator), &time))
    return false;
  *owner = static_cast<DWORD>(value);
  return true;
}

bool IsLogDayDirectory(const WIN32_FIND_DATAW& file) {
  if (!(file.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) ||
      (file.dwFileAttributes & FILE_ATTRIBUTE_REPARSE_POINT))
    return false;
  const std::wstring name = file.cFileName;
  if (name.size() != 10 || name[4] != L'-' || name[7] != L'-') return false;
  FILETIME time{};
  return ParseLogTimestamp(name.substr(0, 4) + name.substr(5, 2) +
                               name.substr(8, 2) + L"-000000-000",
                           &time);
}

// Match only files produced by our collector, including its older timestamp
// format. Leave native logs, running markers and manually saved analysis alone.
bool ParseCrashArtifact(const WIN32_FIND_DATAW& file, CrashArtifact* artifact) {
  if (file.dwFileAttributes &
      (FILE_ATTRIBUTE_DIRECTORY | FILE_ATTRIBUTE_REPARSE_POINT))
    return false;
  const std::wstring name = file.cFileName;
  const auto dump_start = name.find(L".dmp");
  if (dump_start == std::wstring::npos) return false;
  std::wstring timestamp;
  if (name.compare(0, 7, L"native-") == 0) {
    const auto pid_end = name.find(L'-', 7);
    unsigned long long pid = 0;
    if (pid_end == std::wstring::npos || pid_end >= dump_start ||
        !ParseHelperNumber(name.substr(7, pid_end - 7).c_str(), MAXDWORD, &pid))
      return false;
    timestamp = name.substr(pid_end + 1, dump_start - pid_end - 1);
  } else {
    const auto crash_start = name.find(L"-crash-");
    DWORD owner = 0;
    if (crash_start == std::wstring::npos || crash_start + 7 >= dump_start ||
        !ParseLogSession(name.substr(0, crash_start), &owner))
      return false;
    timestamp = name.substr(crash_start + 7, dump_start - crash_start - 7);
    if (timestamp.size() != 19) return false;
  }
  const auto suffix = name.substr(dump_start);
  const bool complete = suffix == L".dmp" || suffix == L".dmp.triage.dmp";
  const bool partial =
      suffix == L".dmp.partial" || suffix == L".dmp.triage.dmp.partial";
  if (!complete && !partial && suffix != L".dmp.txt") return false;
  FILETIME crash_time{};
  if (!ParseLogTimestamp(timestamp, &crash_time)) return false;
  artifact->name = name;
  artifact->base = name.substr(0, dump_start + 4);
  // Legacy names used the process start time. Their file write time is a better
  // approximation of the crash; new names contain the actual crash time.
  artifact->time = timestamp.size() == 19 ? crash_time : file.ftLastWriteTime;
  artifact->partial = partial;
  return true;
}

void PruneCrashDumps(const std::wstring& directory,
                     HANDLE report = INVALID_HANDLE_VALUE) {
  WIN32_FIND_DATAW file{};
  HANDLE search =
      FindFirstFileW((directory + L"\\*.dmp*").c_str(), &file);
  if (search == INVALID_HANDLE_VALUE) return;
  std::vector<CrashArtifact> artifacts;
  do {
    CrashArtifact artifact{};
    if (ParseCrashArtifact(file, &artifact)) artifacts.push_back(artifact);
  } while (FindNextFileW(search, &file));
  const auto scan_error = GetLastError();
  FindClose(search);
  // Never prune based on a partial directory listing.
  if (scan_error != ERROR_NO_MORE_FILES) return;
  FILETIME now{};
  GetSystemTimeAsFileTime(&now);
  ULARGE_INTEGER ticks{};
  ticks.LowPart = now.dwLowDateTime;
  ticks.HighPart = now.dwHighDateTime;
  constexpr ULONGLONG kCrashRetentionTicks = 30ULL * 24 * 60 * 60 * 10000000;
  ticks.QuadPart -= kCrashRetentionTicks;
  const FILETIME cutoff{ticks.LowPart, ticks.HighPart};
  std::set<std::wstring> busy;
  for (const auto& artifact : artifacts) {
    // The helper keeps its report and partial dumps open without SHARE_DELETE.
    // Protect the whole set when another capture (or a reader) is still active.
    HANDLE probe =
        CreateFileW((directory + L"\\" + artifact.name).c_str(), DELETE,
                    FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE,
                    nullptr, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, nullptr);
    if (probe != INVALID_HANDLE_VALUE) {
      CloseHandle(probe);
    } else if (GetLastError() != ERROR_FILE_NOT_FOUND) {
      busy.insert(artifact.base);
    }
  }
  unsigned removed = 0;
  for (const auto& artifact : artifacts) {
    if (busy.count(artifact.base) ||
        (!artifact.partial && CompareFileTime(&artifact.time, &cutoff) >= 0))
      continue;
    if (DeleteFileW((directory + L"\\" + artifact.name).c_str())) {
      ++removed;
    } else {
      const auto error = GetLastError();
      if (error == ERROR_FILE_NOT_FOUND) continue;
      char message[1024]{};
      _snprintf_s(
          message, sizeof(message), _TRUNCATE,
          "Crash dump retention delete failed: Win32 error=%lu file=%ls", error,
          artifact.name.c_str());
      if (report != INVALID_HANDLE_VALUE)
        WriteReport(report, message);
      else
        BangumiNativeLog(message, true);
    }
  }
  if (removed != 0) {
    char message[128]{};
    _snprintf_s(message, sizeof(message), _TRUNCATE,
                "Crash dump retention removed %u expired/partial files", removed);
    if (report != INVALID_HANDLE_VALUE)
      WriteReport(report, message);
    else
      BangumiNativeLog(message);
  }
}

void PruneAllCrashDumps() {
  const auto& root = BangumiNativeLogDirectory();
  PruneCrashDumps(root);  // Legacy flat captures.
  WIN32_FIND_DATAW file{};
  HANDLE search = FindFirstFileW((root + L"\\*").c_str(), &file);
  if (search == INVALID_HANDLE_VALUE) return;
  do {
    if (!IsLogDayDirectory(file)) continue;
    const auto directory = root + L"\\" + file.cFileName + L"\\crashes";
    const auto attributes = GetFileAttributesW(directory.c_str());
    if (attributes != INVALID_FILE_ATTRIBUTES &&
        (attributes & FILE_ATTRIBUTE_DIRECTORY) &&
        !(attributes & FILE_ATTRIBUTE_REPARSE_POINT))
      PruneCrashDumps(directory);
  } while (FindNextFileW(search, &file));
  FindClose(search);
}

LONG WINAPI RecordCrash(EXCEPTION_POINTERS* pointers) {
  if (InterlockedExchange(&handling_crash, 1) != 0) {
    return EXCEPTION_CONTINUE_SEARCH;
  }
  // Name the files for the crash, not for the process's startup time.
  SYSTEMTIME time{};
  GetLocalTime(&time);
  if (_snwprintf_s(dump_file, _countof(dump_file), _TRUNCATE,
                   L"%ls-crash-%04u%02u%02u-%02u%02u%02u-%03u.dmp", dump_stem,
                   time.wYear, time.wMonth, time.wDay, time.wHour, time.wMinute,
                   time.wSecond, time.wMilliseconds) < 0) {
    CrashLog("Crash dump path is too long");
    return EXCEPTION_CONTINUE_SEARCH;
  }
  char message[4096]{};
  auto record = pointers->ExceptionRecord;
  HMODULE module = nullptr;
  wchar_t module_path[MAX_PATH]{};
  GetModuleHandleExW(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS |
                         GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT,
                     reinterpret_cast<LPCWSTR>(record->ExceptionAddress),
                     &module);
  if (module) GetModuleFileNameW(module, module_path, MAX_PATH);
  char module_utf8[1024]{};
  WideCharToMultiByte(CP_UTF8, 0, module_path, -1, module_utf8,
                      sizeof(module_utf8), nullptr, nullptr);
  _snprintf_s(message, sizeof(message), _TRUNCATE,
              "Unhandled native exception code=0x%08lX address=%p "
              "module=%s offset=0x%llX; writing crash dump",
              record->ExceptionCode, record->ExceptionAddress, module_utf8,
              static_cast<unsigned long long>(
                  reinterpret_cast<uintptr_t>(record->ExceptionAddress) -
                  reinterpret_cast<uintptr_t>(module)));
  CrashLog(message);

  // DbgHelp in the crashed process can deadlock on its loader/heap locks.
  // Keep the exception pointers alive while the helper reads them remotely.
  if (_snwprintf_s(crash_command, _countof(crash_command), _TRUNCATE,
                   L"\"%ls\" --bangumi-crash-dump %lu %lu %llu \"%ls\"",
                   executable, GetCurrentProcessId(), GetCurrentThreadId(),
                   static_cast<unsigned long long>(
                       reinterpret_cast<uintptr_t>(pointers)),
                   dump_file) < 0) {
    CrashLog("Crash dump helper command is too long");
    return EXCEPTION_CONTINUE_SEARCH;
  }
  STARTUPINFOW startup{};
  startup.cb = sizeof(startup);
  PROCESS_INFORMATION process{};
  if (CreateProcessW(executable, crash_command, nullptr, nullptr, FALSE,
                     CREATE_NO_WINDOW, nullptr, nullptr, &startup, &process)) {
    const auto result = WaitForSingleObject(process.hProcess, kHelperTimeoutMs);
    const auto wait_error = result == WAIT_FAILED ? GetLastError() : 0;
    if (result == WAIT_TIMEOUT || result == WAIT_FAILED) {
      CrashLog(
          "Crash dump helper did not finish; see .dmp.txt for "
          "completed stages and retain the .triage.dmp");
      if (TerminateProcess(process.hProcess, WAIT_TIMEOUT) &&
          WaitForSingleObject(process.hProcess, 1000) == WAIT_OBJECT_0) {
        wchar_t partial[32768]{};
        _snwprintf_s(partial, _countof(partial), _TRUNCATE, L"%ls.partial",
                     dump_file);
        DeleteFileW(partial);
        _snwprintf_s(partial, _countof(partial), _TRUNCATE,
                     L"%ls.triage.dmp.partial", dump_file);
        DeleteFileW(partial);
      }
    }
    DWORD code = 1;
    GetExitCodeProcess(process.hProcess, &code);
    char dump_utf8[2048]{};
    WideCharToMultiByte(CP_UTF8, 0, dump_file, -1, dump_utf8, sizeof(dump_utf8),
                        nullptr, nullptr);
    _snprintf_s(message, sizeof(message), _TRUNCATE,
                "Crash dump helper wait=%lu wait_error=%lu exit=0x%08lX "
                "path=%s (full); see .triage.dmp and .txt",
                result, wait_error, code, dump_utf8);
    CrashLog(message);
    CloseHandle(process.hThread);
    CloseHandle(process.hProcess);
  } else {
    _snprintf_s(message, sizeof(message), _TRUNCATE,
                "Could not start crash dump helper: Win32 error=%lu",
                GetLastError());
    CrashLog(message);
  }
  return previous_filter ? previous_filter(pointers)
                         : EXCEPTION_CONTINUE_SEARCH;
}

void RecordTerminate() {
  CrashLog("std::terminate: unhandled C++ exception");
  try {
    auto exception = std::current_exception();
    if (exception) std::rethrow_exception(exception);
  } catch (const std::exception& error) {
    CrashLog(error.what());
  } catch (...) {
    CrashLog("Non-standard C++ exception");
  }
  // MSVC's terminate wrapper catches exceptions raised by its handler before
  // aborting. Capture explicitly, rather than relying on the top-level filter.
  CONTEXT context{};
  RtlCaptureContext(&context);
  EXCEPTION_RECORD record{};
  record.ExceptionCode = 0xE000B701;
  record.ExceptionFlags = EXCEPTION_NONCONTINUABLE;
#if defined(_M_X64)
  record.ExceptionAddress = reinterpret_cast<void*>(context.Rip);
#elif defined(_M_IX86)
  record.ExceptionAddress = reinterpret_cast<void*>(context.Eip);
#elif defined(_M_ARM64)
  record.ExceptionAddress = reinterpret_cast<void*>(context.Pc);
#endif
  EXCEPTION_POINTERS pointers{&record, &context};
  RecordCrash(&pointers);
  std::abort();
}

void ReportUncleanRunsIn(const std::wstring& directory, bool legacy) {
  WIN32_FIND_DATAW data{};
  HANDLE search =
      FindFirstFileW((directory + L"\\*.running").c_str(), &data);
  if (search == INVALID_HANDLE_VALUE) return;
  do {
    if (data.dwFileAttributes &
        (FILE_ATTRIBUTE_DIRECTORY | FILE_ATTRIBUTE_REPARSE_POINT))
      continue;
    const std::wstring name = data.cFileName;
    if (name.size() <= 8 || name.substr(name.size() - 8) != L".running")
      continue;
    const auto session = name.substr(0, name.size() - 8);
    DWORD owner = 0;
    if (legacy) {
      unsigned long long value = 0;
      if (session.compare(0, 7, L"native-") != 0 ||
          !ParseHelperNumber(session.substr(7).c_str(), MAXDWORD, &value))
        continue;
      owner = static_cast<DWORD>(value);
    } else if (!ParseLogSession(session, &owner)) {
      continue;
    }
    HANDLE process = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE,
                                 owner);
    if (process) {
      DWORD code = 0;
      FILETIME created{}, exited{}, kernel{}, user{};
      const bool alive =
          GetExitCodeProcess(process, &code) && code == STILL_ACTIVE;
      const bool have_times =
          GetProcessTimes(process, &created, &exited, &kernel, &user) != FALSE;
      const bool same_run =
          !have_times ||
          (legacy ? CompareFileTime(&created, &data.ftCreationTime) <= 0
                  : BangumiLogSessionId(BangumiLogLocalTime(created), owner) ==
                        session);
      CloseHandle(process);
      if (alive && same_run) continue;
    } else if (GetLastError() != ERROR_INVALID_PARAMETER) {
      continue;  // Access denied is not proof of an exited process.
    }
    char message[512]{};
    _snprintf_s(message, sizeof(message), _TRUNCATE,
                "Previous process pid=%lu exited without normal shutdown; "
                "log session=%ls",
                owner, session.c_str());
    BangumiNativeLog(message, true);
    const auto old = directory + L"\\" + data.cFileName;
    MoveFileExW(old.c_str(), (old + L".unclean").c_str(),
                MOVEFILE_REPLACE_EXISTING);
  } while (FindNextFileW(search, &data));
  FindClose(search);
}

void ReportUncleanRuns() {
  const auto& root = BangumiNativeLogDirectory();
  ReportUncleanRunsIn(root, true);
  const auto state = root + L"\\state";
  const auto attributes = GetFileAttributesW(state.c_str());
  if (attributes != INVALID_FILE_ATTRIBUTES &&
      (attributes & FILE_ATTRIBUTE_DIRECTORY) &&
      !(attributes & FILE_ATTRIBUTE_REPARSE_POINT))
    ReportUncleanRunsIn(state, false);
}
}  // namespace

bool RunCrashDumpHelper(int* exit_code) {
  int count = 0;
  auto arguments = CommandLineToArgvW(GetCommandLineW(), &count);
  if (!arguments) return false;
  if (count < 2 || wcscmp(arguments[1], L"--bangumi-crash-dump") != 0) {
    LocalFree(arguments);
    return false;
  }
  *exit_code = 1;
  if (count == 6) {
    unsigned long long owner_value = 0, thread_value = 0, address = 0;
    if (!ParseHelperNumber(arguments[2], MAXDWORD, &owner_value) ||
        !ParseHelperNumber(arguments[3], MAXDWORD, &thread_value) ||
        !ParseHelperNumber(arguments[4], std::numeric_limits<uintptr_t>::max(),
                           &address) ||
        *arguments[5] == L'\0') {
      *exit_code = ERROR_INVALID_PARAMETER;
      LocalFree(arguments);
      return true;
    }
    const auto owner = static_cast<DWORD>(owner_value);
    const auto thread = static_cast<DWORD>(thread_value);
    const std::wstring path = arguments[5];
    HANDLE report =
        CreateFileW((path + L".txt").c_str(), GENERIC_WRITE, FILE_SHARE_READ,
                    nullptr, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, nullptr);
    // HandleData requires DUP_HANDLE in addition to the original read rights.
    HANDLE process = OpenProcess(
        PROCESS_QUERY_INFORMATION | PROCESS_VM_READ | PROCESS_DUP_HANDLE, FALSE,
        owner);
    if (process) {
      WriteCaptureDetails(report, process, owner, thread,
                          static_cast<uintptr_t>(address));
      MINIDUMP_EXCEPTION_INFORMATION exception{};
      exception.ThreadId = thread;
      exception.ExceptionPointers = reinterpret_cast<EXCEPTION_POINTERS*>(
          static_cast<uintptr_t>(address));
      exception.ClientPointers = TRUE;
      const auto triage_type = static_cast<MINIDUMP_TYPE>(
          kCommonDumpFlags | MiniDumpWithIndirectlyReferencedMemory);
      const auto triage =
          WriteDump(process, owner, &exception, path + L".triage.dmp",
                    triage_type, kTriageTimeoutMs, report, "triage");
      const auto separator = path.find_last_of(L"\\/");
      const auto directory = separator == std::wstring::npos
                                 ? std::wstring(L".")
                                 : path.substr(0, separator);
      // Clean expired captures once the new triage dump is safely published.
      if (triage == ERROR_SUCCESS) PruneCrashDumps(directory, report);
      const auto full_type =
          static_cast<MINIDUMP_TYPE>(kCommonDumpFlags | MiniDumpWithFullMemory);
      const auto full = WriteDump(process, owner, &exception, path, full_type,
                                  kFullTimeoutMs, report, "full");
      // A successful small dump must not hide a failed full-memory capture.
      *exit_code = static_cast<int>(full);
      WriteReport(report, full == ERROR_SUCCESS ? "capture_result=full"
                          : triage == ERROR_SUCCESS
                              ? "capture_result=triage_only"
                              : "capture_result=failed");
      if (full == ERROR_SUCCESS) PruneCrashDumps(directory, report);
      CloseHandle(process);
    } else {
      const auto error = GetLastError();
      *exit_code = static_cast<int>(error);
      char message[128]{};
      _snprintf_s(message, sizeof(message), _TRUNCATE,
                  "open_process_failed=0x%08lX", error);
      WriteReport(report, message);
    }
    if (report != INVALID_HANDLE_VALUE) CloseHandle(report);
  } else {
    *exit_code = ERROR_INVALID_PARAMETER;
  }
  LocalFree(arguments);
  return true;
}

void StartNativeDiagnostics() {
  GetModuleFileNameW(nullptr, executable, _countof(executable));
  const auto& session = BangumiNativeLogSessionId();
  const auto crashes = BangumiNativeLogSessionDirectory() + L"\\crashes";
  CreateDirectoryW(crashes.c_str(), nullptr);
  const auto stem = crashes + L"\\" + session;
  wcscpy_s(dump_stem, stem.c_str());
  crash_log =
      CreateFileW(BangumiNativeLogFile().c_str(), FILE_APPEND_DATA,
                  FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE,
                  nullptr, OPEN_ALWAYS, FILE_ATTRIBUTE_NORMAL, nullptr);
  previous_filter = SetUnhandledExceptionFilter(RecordCrash);
  std::set_terminate(RecordTerminate);
  char started[256]{};
  _snprintf_s(started, sizeof(started), _TRUNCATE,
              "Process started; native crash diagnostics installed; session=%ls",
              session.c_str());
  BangumiNativeLog(started);
#ifdef FLUTTER_VERSION
  BangumiNativeLog("Application version=" FLUTTER_VERSION);
#endif
#ifdef BANGUMI_FLUTTER_SDK_VERSION
  BangumiNativeLog("Flutter SDK=" BANGUMI_FLUTTER_SDK_VERSION);
#endif
#ifdef BANGUMI_FLUTTER_ENGINE_REVISION
  BangumiNativeLog("Flutter engine=" BANGUMI_FLUTTER_ENGINE_REVISION);
#endif
  ReportUncleanRuns();
  // Also retry cleanup after a helper was killed before it could finish.
  PruneAllCrashDumps();
  const auto state = BangumiNativeLogDirectory() + L"\\state";
  CreateDirectoryW(state.c_str(), nullptr);
  running_file = state + L"\\" + session + L".running";
  HANDLE marker =
      CreateFileW(running_file.c_str(), GENERIC_WRITE, FILE_SHARE_READ, nullptr,
                  CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, nullptr);
  if (marker != INVALID_HANDLE_VALUE) CloseHandle(marker);
}

void FinishNativeDiagnostics() {
  BangumiNativeLog("Process exited normally");
  if (!running_file.empty()) DeleteFileW(running_file.c_str());
  if (crash_log != INVALID_HANDLE_VALUE) {
    CloseHandle(crash_log);
    crash_log = INVALID_HANDLE_VALUE;
  }
}
