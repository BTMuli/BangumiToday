#include "crash_handler.h"

#include <windows.h>
#include <dbghelp.h>
#include <shellapi.h>

#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <exception>
#include <string>

#include "playback/native_log.h"

namespace {
wchar_t executable[32768]{};
wchar_t dump_file[32768]{};
std::wstring running_file;
LPTOP_LEVEL_EXCEPTION_FILTER previous_filter = nullptr;
volatile LONG handling_crash = 0;
wchar_t crash_command[65536]{};

LONG WINAPI RecordCrash(EXCEPTION_POINTERS* pointers) {
  if (InterlockedExchange(&handling_crash, 1) != 0) {
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
  BangumiNativeLog(message, true);

  // DbgHelp in the crashed process can deadlock on its loader/heap locks.
  // Keep the exception pointers alive while the helper reads them remotely.
  _snwprintf_s(crash_command, _countof(crash_command), _TRUNCATE,
               L"\"%ls\" --bangumi-crash-dump %lu %lu %llu \"%ls\"",
               executable, GetCurrentProcessId(), GetCurrentThreadId(),
               static_cast<unsigned long long>(
                   reinterpret_cast<uintptr_t>(pointers)),
               dump_file);
  STARTUPINFOW startup{};
  startup.cb = sizeof(startup);
  PROCESS_INFORMATION process{};
  if (CreateProcessW(executable, crash_command, nullptr, nullptr, FALSE,
                     CREATE_NO_WINDOW, nullptr, nullptr, &startup, &process)) {
    const auto result = WaitForSingleObject(process.hProcess, 8000);
    if (result == WAIT_TIMEOUT) {
      BangumiNativeLog("Crash dump helper timed out; dump may be incomplete", true);
      TerminateProcess(process.hProcess, WAIT_TIMEOUT);
      WaitForSingleObject(process.hProcess, 1000);
    }
    DWORD code = 1;
    GetExitCodeProcess(process.hProcess, &code);
    char dump_utf8[2048]{};
    WideCharToMultiByte(CP_UTF8, 0, dump_file, -1, dump_utf8,
                        sizeof(dump_utf8), nullptr, nullptr);
    _snprintf_s(message, sizeof(message), _TRUNCATE,
                "Crash dump helper wait=%lu exit=%lu path=%s", result, code,
                dump_utf8);
    BangumiNativeLog(message, true);
    CloseHandle(process.hThread);
    CloseHandle(process.hProcess);
  } else {
    _snprintf_s(message, sizeof(message), _TRUNCATE,
                "Could not start crash dump helper: Win32 error=%lu",
                GetLastError());
    BangumiNativeLog(message, true);
  }
  return previous_filter ? previous_filter(pointers) : EXCEPTION_CONTINUE_SEARCH;
}

void RecordTerminate() {
  BangumiNativeLog("std::terminate: unhandled C++ exception", true);
  try {
    auto exception = std::current_exception();
    if (exception) std::rethrow_exception(exception);
  } catch (const std::exception& error) {
    BangumiNativeLog(error.what(), true);
  } catch (...) {
    BangumiNativeLog("Non-standard C++ exception", true);
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

void ReportUncleanRuns() {
  WIN32_FIND_DATAW data{};
  const auto directory = BangumiNativeLogDirectory();
  HANDLE search = FindFirstFileW((directory + L"\\native-*.running").c_str(),
                                 &data);
  if (search == INVALID_HANDLE_VALUE) return;
  do {
    wchar_t* end = nullptr;
    const auto owner = wcstoul(data.cFileName + 7, &end, 10);
    if (owner == 0 || wcscmp(end, L".running") != 0) continue;
    HANDLE process = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE,
                                 static_cast<DWORD>(owner));
    if (process) {
      DWORD code = 0;
      FILETIME created{}, exited{}, kernel{}, user{};
      const bool alive = GetExitCodeProcess(process, &code) && code == STILL_ACTIVE;
      const bool same_run =
          !GetProcessTimes(process, &created, &exited, &kernel, &user) ||
          CompareFileTime(&created, &data.ftCreationTime) <= 0;
      CloseHandle(process);
      if (alive && same_run) continue;
    } else if (GetLastError() != ERROR_INVALID_PARAMETER) {
      continue;  // Access denied is not proof of an exited process.
    }
    char message[256]{};
    _snprintf_s(message, sizeof(message), _TRUNCATE,
                "Previous process pid=%lu exited without normal shutdown; "
                "see native-%lu.log and playback logs", owner, owner);
    BangumiNativeLog(message, true);
    const auto old = directory + L"\\" + data.cFileName;
    MoveFileExW(old.c_str(), (old + L".unclean").c_str(),
                MOVEFILE_REPLACE_EXISTING);
  } while (FindNextFileW(search, &data));
  FindClose(search);
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
    const auto owner = static_cast<DWORD>(wcstoul(arguments[2], nullptr, 10));
    const auto thread = static_cast<DWORD>(wcstoul(arguments[3], nullptr, 10));
    const auto address = _wcstoui64(arguments[4], nullptr, 10);
    HANDLE process = OpenProcess(PROCESS_QUERY_INFORMATION | PROCESS_VM_READ,
                                 FALSE, owner);
    HANDLE file = CreateFileW(arguments[5], GENERIC_WRITE, FILE_SHARE_READ,
                              nullptr, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL,
                              nullptr);
    if (process && file != INVALID_HANDLE_VALUE) {
      MINIDUMP_EXCEPTION_INFORMATION exception{};
      exception.ThreadId = thread;
      exception.ExceptionPointers =
          reinterpret_cast<EXCEPTION_POINTERS*>(static_cast<uintptr_t>(address));
      exception.ClientPointers = TRUE;
      const auto type = static_cast<MINIDUMP_TYPE>(
          MiniDumpNormal | MiniDumpWithThreadInfo | MiniDumpWithUnloadedModules);
      if (MiniDumpWriteDump(process, owner, file, type, &exception, nullptr,
                            nullptr)) {
        FlushFileBuffers(file);
        *exit_code = 0;
      } else {
        *exit_code = static_cast<int>(GetLastError());
      }
    }
    if (file != INVALID_HANDLE_VALUE) CloseHandle(file);
    if (process) CloseHandle(process);
  }
  LocalFree(arguments);
  return true;
}

void StartNativeDiagnostics() {
  GetModuleFileNameW(nullptr, executable, _countof(executable));
  const auto stem = BangumiNativeLogDirectory() + L"\\native-" +
                    std::to_wstring(GetCurrentProcessId());
  SYSTEMTIME time{};
  GetLocalTime(&time);
  _snwprintf_s(dump_file, _countof(dump_file), _TRUNCATE,
               L"%ls-%04u%02u%02u-%02u%02u%02u.dmp", stem.c_str(), time.wYear,
               time.wMonth, time.wDay, time.wHour, time.wMinute, time.wSecond);
  previous_filter = SetUnhandledExceptionFilter(RecordCrash);
  std::set_terminate(RecordTerminate);
  BangumiNativeLog("Process started; native crash diagnostics installed");
#ifdef FLUTTER_VERSION
  BangumiNativeLog("Application version=" FLUTTER_VERSION);
#endif
  ReportUncleanRuns();
  running_file = stem + L".running";
  HANDLE marker = CreateFileW(running_file.c_str(), GENERIC_WRITE, FILE_SHARE_READ,
                              nullptr, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL,
                              nullptr);
  if (marker != INVALID_HANDLE_VALUE) CloseHandle(marker);
}

void FinishNativeDiagnostics() {
  BangumiNativeLog("Process exited normally");
  if (!running_file.empty()) DeleteFileW(running_file.c_str());
}
