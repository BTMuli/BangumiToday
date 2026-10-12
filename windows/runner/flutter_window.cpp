#include "flutter_window.h"

#include <cstdlib>
#include <optional>

#include <desktop_multi_window/desktop_multi_window_plugin.h>
#include <dwmapi.h>
#include <flutter/standard_method_codec.h>

#include "../playback/native_log.h"
#include "playback_plugin_registrant.h"

namespace {
DWORD WINAPI EnforceApplicationExit(LPVOID) {
  // This thread must survive a blocked Dart FFI call, COM shutdown or engine
  // destructor. It is started only after playback and persistence are closed.
  Sleep(10000);
  BangumiNativeLog(
      "Application data cleanup completed, but native teardown exceeded 10s; "
      "terminating the remaining process", true);
  TerminateProcess(GetCurrentProcess(), EXIT_SUCCESS);
  return 0;
}
}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {
  // WM_QUIT can end the loop before WM_DESTROY. Tear down while OnDestroy
  // still dispatches to this class, clearing the controller before Flutter's
  // child HWND destruction sends messages back to the parent.
  Destroy();
}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  DesktopMultiWindowSetWindowCreatedCallback([](void* controller) {
    auto* view = static_cast<flutter::FlutterViewController*>(controller);
    // Frameless playback windows need an explicit rounding preference. The
    // playback frame channel disables rounding when entering screen fullscreen.
    // Use numeric values so older Windows SDK headers remain supported.
    constexpr DWORD kWindowCornerPreference = 33;  // DWMWA_WINDOW_CORNER_PREFERENCE
    constexpr DWORD kRoundCorners = 2;  // DWMWCP_ROUND
    HWND window = GetAncestor(view->view()->GetNativeWindow(), GA_ROOT);
    DwmSetWindowAttribute(window, kWindowCornerPreference, &kRoundCorners,
                          sizeof(kRoundCorners));
    RegisterPlaybackPlugins(view);
  });
  RegisterMainPlugins(flutter_controller_->engine());
  exit_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(),
          "bangumi_today/application_exit",
          &flutter::StandardMethodCodec::GetInstance());
  exit_channel_->SetMethodCallHandler([this](const auto& call, auto result) {
    if (call.method_name() != "armExitTimeout") {
      result->NotImplemented();
      return;
    }
    if (!exit_timeout_armed_) {
      HANDLE thread =
          CreateThread(nullptr, 0, EnforceApplicationExit, nullptr, 0, nullptr);
      if (!thread) {
        result->Error("exit_timeout_failed", "Could not start exit timeout.");
        return;
      }
      CloseHandle(thread);
      exit_timeout_armed_ = true;
      BangumiNativeLog("Application cleanup completed; native exit timeout armed");
    }
    result->Success();
  });
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (exit_channel_) {
    exit_channel_->SetMethodCallHandler(nullptr);
    exit_channel_ = nullptr;
  }
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      if (flutter_controller_) {
        flutter_controller_->engine()->ReloadSystemFonts();
      }
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
