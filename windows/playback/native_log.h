#ifndef BANGUMI_NATIVE_LOG_H_
#define BANGUMI_NATIVE_LOG_H_

#include <windows.h>
#include <shlobj.h>

#include <cstdio>
#include <string>

#pragma comment(lib, "shell32.lib")
#pragma comment(lib, "ole32.lib")

// Both the runner and renderer write here, including before Dart starts.
// One append-only WriteFile per record; no iostream buffer or application lock
// is needed on a failing render thread. File names are shared by PID.
inline const std::wstring& BangumiNativeLogDirectory() {
  static const std::wstring directory = [] {
    PWSTR documents = nullptr;
    std::wstring root;
    if (SUCCEEDED(SHGetKnownFolderPath(FOLDERID_Documents, 0, nullptr,
                                      &documents))) {
      root = documents;
      CoTaskMemFree(documents);
    } else {
      wchar_t temporary[MAX_PATH]{};
      GetTempPathW(MAX_PATH, temporary);
      root = temporary;
    }
    root += L"\\BangumiToday";
    CreateDirectoryW(root.c_str(), nullptr);
    root += L"\\log";
    CreateDirectoryW(root.c_str(), nullptr);
    return root;
  }();
  return directory;
}

inline void BangumiNativeLog(const char* message, bool error = false) noexcept {
  try {
    const auto file = BangumiNativeLogDirectory() + L"\\native-" +
                      std::to_wstring(GetCurrentProcessId()) + L".log";
    HANDLE handle = CreateFileW(
        file.c_str(), FILE_APPEND_DATA,
        FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE, nullptr,
        OPEN_ALWAYS, FILE_ATTRIBUTE_NORMAL, nullptr);
    if (handle == INVALID_HANDLE_VALUE) {
      OutputDebugStringA(message);
      return;
    }
    SYSTEMTIME time{};
    GetLocalTime(&time);
    char line[4096]{};
    _snprintf_s(line, sizeof(line), _TRUNCATE,
                "%04u-%02u-%02u %02u:%02u:%02u.%03u [%s pid=%lu tid=%lu] %s\r\n",
                time.wYear, time.wMonth, time.wDay, time.wHour, time.wMinute,
                time.wSecond, time.wMilliseconds, error ? "ERROR" : "INFO",
                GetCurrentProcessId(), GetCurrentThreadId(), message);
    DWORD written = 0;
    WriteFile(handle, line, static_cast<DWORD>(strlen(line)), &written, nullptr);
    if (error) FlushFileBuffers(handle);
    CloseHandle(handle);
  } catch (...) {
    OutputDebugStringA("BangumiToday: native log write failed\n");
  }
}

// Failed GPU calls can recur for every frame. Keep their first detailed cause,
// then periodically report how many repetitions were skipped.
inline void BangumiNativeGraphicsError(const char* message) noexcept {
  thread_local ULONGLONG last = 0;
  thread_local unsigned suppressed = 0;
  const auto now = GetTickCount64();
  if (last != 0 && now - last < 5000) {
    ++suppressed;
    return;
  }
  if (suppressed != 0) {
    char summary[128]{};
    _snprintf_s(summary, sizeof(summary), _TRUNCATE,
                "Suppressed %u repeated GPU errors", suppressed);
    BangumiNativeLog(summary, true);
    suppressed = 0;
  }
  BangumiNativeLog(message, true);
  last = now;
}

#endif  // BANGUMI_NATIVE_LOG_H_
