#include "playback_plugin_registrant.h"

#include <dwmapi.h>
#include <flutter/flutter_view_controller.h>
#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>
#include <shobjidl_core.h>
#include <wrl/client.h>

#include <cwchar>
#include <optional>
#include <vector>

#include <file_selector_windows/file_selector_windows.h>
#include <irondash_engine_context/irondash_engine_context_plugin_c_api.h>
#include <media_kit_libs_windows_video/media_kit_libs_windows_video_plugin_c_api.h>
#include <media_kit_video/media_kit_video_plugin_c_api.h>
#include <screen_retriever_windows/screen_retriever_windows_plugin_c_api.h>
#include <super_native_extensions/super_native_extensions_plugin_c_api.h>
#include <url_launcher_windows/url_launcher_windows.h>
#include <window_manager/window_manager_plugin.h>

#include "../playback/native_log.h"

namespace {
void SkipMainVideoRegistration(FlutterDesktopPluginRegistrarRef) {}

// libmpv renders into a Flutter texture and does not own a monitor. Query the
// display containing this engine's window, including after a monitor move.
std::optional<double> PlaybackDisplayRefreshRate(HWND window) {
  const auto monitor = MonitorFromWindow(window, MONITOR_DEFAULTTONEAREST);
  MONITORINFOEXW info{};
  info.cbSize = sizeof(info);
  if (!GetMonitorInfoW(monitor, &info)) return std::nullopt;

  // DisplayConfig retains fractional rates such as 60000/1001 Hz. The active
  // topology can change between the buffer-size query and the actual query.
  for (int attempt = 0; attempt < 3; ++attempt) {
    UINT32 path_count = 0;
    UINT32 mode_count = 0;
    if (GetDisplayConfigBufferSizes(QDC_ONLY_ACTIVE_PATHS, &path_count,
                                   &mode_count) != ERROR_SUCCESS) {
      break;
    }
    std::vector<DISPLAYCONFIG_PATH_INFO> paths(path_count);
    std::vector<DISPLAYCONFIG_MODE_INFO> modes(mode_count);
    const auto status = QueryDisplayConfig(
        QDC_ONLY_ACTIVE_PATHS, &path_count, paths.data(), &mode_count,
        modes.data(), nullptr);
    if (status == ERROR_INSUFFICIENT_BUFFER) continue;
    if (status != ERROR_SUCCESS) break;
    for (UINT32 index = 0; index < path_count; ++index) {
      const auto& path = paths[index];
      DISPLAYCONFIG_SOURCE_DEVICE_NAME source{};
      source.header.type = DISPLAYCONFIG_DEVICE_INFO_GET_SOURCE_NAME;
      source.header.size = sizeof(source);
      source.header.adapterId = path.sourceInfo.adapterId;
      source.header.id = path.sourceInfo.id;
      if (DisplayConfigGetDeviceInfo(&source.header) != ERROR_SUCCESS ||
          std::wcscmp(source.viewGdiDeviceName, info.szDevice) != 0) {
        continue;
      }
      const auto& rate = path.targetInfo.refreshRate;
      if (rate.Denominator && rate.Numerator > rate.Denominator) {
        return static_cast<double>(rate.Numerator) / rate.Denominator;
      }
    }
    break;
  }
  // Older display drivers or remote sessions may not support DisplayConfig.
  DEVMODEW mode{};
  mode.dmSize = sizeof(mode);
  if (EnumDisplaySettingsExW(info.szDevice, ENUM_CURRENT_SETTINGS, &mode, 0) &&
      mode.dmDisplayFrequency > 1) {
    return static_cast<double>(mode.dmDisplayFrequency);
  }
  return std::nullopt;
}

// window_manager owns fullscreen bounds and restoration. Keep the independent
// video window caption-free from its first show, including native frame paints.
class PlaybackWindowFramePlugin : public flutter::Plugin {
 public:
  PlaybackWindowFramePlugin(flutter::PluginRegistrarWindows* registrar,
                            flutter::FlutterViewController* controller)
      : registrar_(registrar),
        controller_(controller),
        channel_(std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
            registrar->messenger(), "bangumi_today/playback_window_frame",
            &flutter::StandardMethodCodec::GetInstance())) {
    display_delegate_ = registrar_->RegisterTopLevelWindowProcDelegate(
        [this](HWND window, UINT message, WPARAM wparam,
               LPARAM) -> std::optional<LRESULT> {
          if (message == WM_DISPLAYCHANGE || message == WM_SETTINGCHANGE) {
            display_rate_cached_ = false;
          }
          // NCCALCSIZE alone only removes the non-client layout. During style
          // restoration DefWindowProc can still paint the classic resize frame
          // over the Flutter surface until its next frame arrives.
          if (frameless_video_ && message == WM_NCPAINT) return 0;
          if (fullscreen_ && message == WM_ACTIVATE) {
            // Re-raise and re-mark on activation: the shell can have restored
            // the taskbar while another window was in front. Native activation
            // keeps this synchronous, before another app is shown.
            UpdatePresentation(window, LOWORD(wparam) != WA_INACTIVE);
          }
          if (message == WM_TIMER &&
              wparam == reinterpret_cast<UINT_PTR>(this)) {
            // KillTimer cannot remove an already queued timer message.
            if (transition_ticket_ && GetTickCount64() >= transition_deadline_) {
              BangumiNativeLog("Playback window transition timed out", true);
              RevealTransition();
              if (transition_result_) {
                auto result = std::move(transition_result_);
                result->Error("transition_timeout",
                              "Playback frame did not finish in time.");
              }
            }
            return 0;
          }
          return std::nullopt;
        });
    channel_->SetMethodCallHandler([this](const auto& call, auto result) {
      if (call.method_name() != "setFullscreenFrame" &&
          call.method_name() != "setAlwaysOnTop" &&
          call.method_name() != "getDisplayRefreshRate" &&
          call.method_name() != "beginFullscreenTransition" &&
          call.method_name() != "finishFullscreenTransition" &&
          call.method_name() != "abortFullscreenTransition") {
        result->NotImplemented();
        return;
      }
      auto* view = registrar_->GetView();
      HWND window = view ? GetAncestor(view->GetNativeWindow(), GA_ROOT) : nullptr;
      if (!window || !IsWindow(window)) {
        result->Error("window_unavailable", "Playback window is unavailable.");
        return;
      }
      if (call.method_name() == "setAlwaysOnTop") {
        const auto* pinned = call.arguments()
                                 ? std::get_if<bool>(call.arguments())
                                 : nullptr;
        if (!pinned) {
          result->Error("invalid_argument", "Expected an always-on-top boolean.");
          return;
        }
        always_on_top_ = *pinned;
        if (!UpdatePresentation(window, GetForegroundWindow() == window)) {
          result->Error("z_order_update_failed", "Could not update playback order.");
          return;
        }
        result->Success();
        return;
      }
      if (call.method_name() == "beginFullscreenTransition") {
        if (!controller_ || transition_ticket_) {
          result->Error("transition_unavailable",
                        "Playback window cannot begin another transition.");
          return;
        }
        // Cloaking hides the surface while keeping Flutter visible to its
        // engine. ShowWindow(SW_HIDE) can suspend rendering and frame callbacks.
        const bool was_foreground = GetForegroundWindow() == window;
        const BOOL cloak = TRUE;
        if (FAILED(DwmSetWindowAttribute(window, DWMWA_CLOAK, &cloak,
                                         sizeof(cloak)))) {
          result->Error("transition_hide_failed", "Could not hide playback.");
          return;
        }
        transition_window_ = window;
        transition_was_foreground_ = was_foreground;
        transition_foreground_ = GetForegroundWindow();
        transition_ticket_ = std::make_shared<int>(0);
        transition_deadline_ = GetTickCount64() + 3000;
        // This is a recovery deadline, not a delay in the normal transition.
        if (!SetTimer(window, reinterpret_cast<UINT_PTR>(this), 3000, nullptr)) {
          RevealTransition();
          result->Error("transition_hide_failed", "Could not guard playback.");
          return;
        }
        DwmFlush();
        BangumiNativeLog("Playback window transition hidden");
        result->Success();
        return;
      }
      if (call.method_name() == "abortFullscreenTransition") {
        const bool revealed = RevealTransition();
        if (transition_result_) {
          auto pending = std::move(transition_result_);
          pending->Error("transition_aborted", "Playback transition aborted.");
        }
        if (revealed) {
          result->Success();
        } else {
          result->Error("transition_show_failed", "Could not reveal playback.");
        }
        return;
      }
      if (call.method_name() == "finishFullscreenTransition") {
        if (!controller_ || !transition_ticket_ || transition_result_) {
          result->Error("transition_unavailable",
                        "Playback window has no transition to finish.");
          return;
        }
        transition_result_ = std::move(result);
        std::weak_ptr<int> ticket = transition_ticket_;
        controller_->engine()->SetNextFrameCallback([this, ticket] {
          // An aborted transition or destroyed plugin invalidates the callback.
          if (ticket.expired()) return;
          const bool revealed = RevealTransition();
          auto completed = std::move(transition_result_);
          if (revealed) {
            BangumiNativeLog("Playback window transition frame drawn and revealed");
            completed->Success();
          } else {
            completed->Error("transition_show_failed",
                             "Could not reveal playback.");
          }
        });
        controller_->ForceRedraw();
        return;
      }
      if (call.method_name() == "getDisplayRefreshRate") {
        const auto monitor = MonitorFromWindow(window, MONITOR_DEFAULTTONEAREST);
        // DisplayConfig can enter the display driver. OSD's one-second ticks
        // only read the cache; monitor/topology changes refresh it once.
        if (!display_rate_cached_ || display_monitor_ != monitor) {
          display_rate_ = PlaybackDisplayRefreshRate(window);
          display_monitor_ = monitor;
          display_rate_cached_ = true;
        }
        result->Success(display_rate_ ? flutter::EncodableValue(*display_rate_)
                                      : flutter::EncodableValue());
        return;
      }
      const auto* fullscreen = call.arguments()
                                   ? std::get_if<bool>(call.arguments())
                                   : nullptr;
      if (!fullscreen) {
        result->Error("invalid_argument", "Expected a fullscreen boolean.");
        return;
      }
      if (*fullscreen && !taskbar_) {
        auto status = CoCreateInstance(CLSID_TaskbarList, nullptr,
                                       CLSCTX_INPROC_SERVER,
                                       IID_PPV_ARGS(taskbar_.GetAddressOf()));
        if (SUCCEEDED(status)) status = taskbar_->HrInit();
        if (FAILED(status)) {
          taskbar_.Reset();
          result->Error("taskbar_unavailable", "Could not initialize taskbar.");
          return;
        }
      }
      frameless_video_ = true;
      // Apply this before the first show as well as fullscreen transitions.
      // DWM must not animate a cached native frame over the video surface.
      const BOOL disable_transitions = TRUE;
      DwmSetWindowAttribute(window, DWMWA_TRANSITIONS_FORCEDISABLED,
                            &disable_transitions, sizeof(disable_transitions));
      const auto style = GetWindowLongPtr(window, GWL_STYLE);
      // The windowed baseline keeps resizing and snapping, but never a caption.
      // Fullscreen also clears WS_MAXIMIZE so NCCALCSIZE does not compensate
      // for maximized resize borders when filling the entire monitor.
      const auto decorations = *fullscreen
                                   ? (WS_OVERLAPPEDWINDOW | WS_MAXIMIZE)
                                   : WS_CAPTION;
      SetLastError(ERROR_SUCCESS);
      if (!SetWindowLongPtr(window, GWL_STYLE, style & ~decorations) &&
          GetLastError() != ERROR_SUCCESS) {
        result->Error("frame_update_failed", "Could not remove window styles.");
        return;
      }
      // Numeric values keep older Windows SDK headers supported. Windows 10
      // ignores these unsupported DWM attributes; removing the styles suffices.
      constexpr DWORD kCornerPreference = 33;  // DWMWA_WINDOW_CORNER_PREFERENCE
      constexpr DWORD kBorderColor = 34;       // DWMWA_BORDER_COLOR
      const DWORD corners = *fullscreen ? 1 : 2;  // DONOTROUND / ROUND
      const COLORREF border = 0xfffffffe;  // DWMWA_COLOR_NONE in both modes
      DwmSetWindowAttribute(window, kCornerPreference, &corners, sizeof(corners));
      DwmSetWindowAttribute(window, kBorderColor, &border, sizeof(border));
      // On exit, window_manager restores the caption-free windowed baseline.
      MONITORINFO monitor{};
      monitor.cbSize = sizeof(monitor);
      if (*fullscreen &&
          !GetMonitorInfo(MonitorFromWindow(window, MONITOR_DEFAULTTONEAREST),
                          &monitor)) {
        result->Error("frame_update_failed", "Could not find playback monitor.");
        return;
      }
      const auto& bounds = monitor.rcMonitor;
      const UINT flags = SWP_NOZORDER | SWP_NOACTIVATE | SWP_FRAMECHANGED |
                         (*fullscreen ? 0 : (SWP_NOMOVE | SWP_NOSIZE));
      if (!SetWindowPos(window, nullptr, bounds.left, bounds.top,
                        bounds.right - bounds.left, bounds.bottom - bounds.top,
                        flags)) {
        result->Error("frame_update_failed", "Could not refresh the window frame.");
        return;
      }
      RECT actual{};
      RECT client{};
      if (!GetWindowRect(window, &actual) || !GetClientRect(window, &client) ||
          (*fullscreen &&
           (!EqualRect(&actual, &bounds) ||
            client.right - client.left != bounds.right - bounds.left ||
            client.bottom - client.top != bounds.bottom - bounds.top))) {
        result->Error("frame_update_failed", "Playback did not fill the monitor.");
        return;
      }
      // desktop_multi_window also queues a child resize. Synchronize it now so
      // the next Flutter frame has the final viewport before revealing it.
      if (!SetWindowPos(view->GetNativeWindow(), nullptr, 0, 0,
                        client.right - client.left, client.bottom - client.top,
                        SWP_NOZORDER | SWP_NOACTIVATE)) {
        result->Error("frame_update_failed", "Could not resize playback viewport.");
        return;
      }
      fullscreen_ = *fullscreen;
      if (!UpdatePresentation(window, GetForegroundWindow() == window)) {
        result->Error("z_order_update_failed", "Could not update fullscreen order.");
        return;
      }
      char frame_log[256]{};
      _snprintf_s(frame_log, sizeof(frame_log), _TRUNCATE,
                  "Playback window frame fullscreen=%d bounds={%ld,%ld,%ld,%ld} viewport=%ldx%ld",
                  *fullscreen ? 1 : 0, actual.left, actual.top, actual.right,
                  actual.bottom, client.right - client.left,
                  client.bottom - client.top);
      BangumiNativeLog(frame_log);
      result->Success();
    });
  }

  ~PlaybackWindowFramePlugin() override {
    transition_was_foreground_ = false;
    fullscreen_ = false;
    RevealTransition();
    registrar_->UnregisterTopLevelWindowProcDelegate(display_delegate_);
  }

 private:
  bool UpdatePresentation(HWND window, bool active) {
    // SetWindowPos can synchronously send window messages back to this plugin.
    if (updating_presentation_) return true;
    updating_presentation_ = true;
    const bool presented = !transition_window_;
    // Fullscreen never pins the window. Only the user's always-on-top
    // preference enters the topmost band; fullscreen stays in the ordinary band
    // and lets the shell hide the taskbar for the marked fullscreen window.
    // Promoting to topmost there would also place the player above every other
    // topmost window, which is what hid overlay layers such as the NVIDIA one.
    const bool topmost = always_on_top_;
    const bool was_topmost =
        (GetWindowLongPtr(window, GWL_EXSTYLE) & WS_EX_TOPMOST) != 0;
    bool updated = true;
    DWORD order_error = ERROR_SUCCESS;
    if (topmost != was_topmost) {
      updated = SetWindowPos(window, topmost ? HWND_TOPMOST : HWND_NOTOPMOST,
                              0, 0, 0, 0,
                              SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE |
                                  SWP_NOOWNERZORDER) != FALSE;
      if (!updated) order_error = GetLastError();
    } else if (fullscreen_ && active && presented) {
      // Reassert on activation/reveal: the taskbar and other windows can have
      // risen while the surface was DWM-cloaked. An unpinned window only
      // re-enters the top of the ordinary band, so topmost windows still draw
      // above the video; a pinned one keeps the top of the topmost band.
      updated = SetWindowPos(window, topmost ? HWND_TOPMOST : HWND_TOP, 0, 0, 0,
                             0,
                             SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE |
                                 SWP_NOOWNERZORDER) != FALSE;
      if (!updated) order_error = GetLastError();
    }
    HRESULT marked = S_OK;
    if (taskbar_ && (presented || !fullscreen_)) {
      marked = taskbar_->MarkFullscreenWindow(window, fullscreen_ ? TRUE : FALSE);
    }
    const bool actual_topmost =
        (GetWindowLongPtr(window, GWL_EXSTYLE) & WS_EX_TOPMOST) != 0;
    updated = updated && actual_topmost == topmost;
    char log[256]{};
    _snprintf_s(log, sizeof(log), _TRUNCATE,
                "Playback window order fullscreen=%d active=%d pinned=%d topmost=%d cloaked=%d updated=%d error=%lu taskbar=0x%08lx",
                fullscreen_ ? 1 : 0, active ? 1 : 0, always_on_top_ ? 1 : 0,
                actual_topmost ? 1 : 0, presented ? 0 : 1, updated ? 1 : 0,
                order_error,
                static_cast<unsigned long>(marked));
    BangumiNativeLog(log, !updated || FAILED(marked));
    updating_presentation_ = false;
    return updated && SUCCEEDED(marked);
  }

  bool RevealTransition() {
    transition_ticket_.reset();
    if (!transition_window_) return true;
    const HWND window = transition_window_;
    KillTimer(window, reinterpret_cast<UINT_PTR>(this));
    if (!IsWindow(window)) {
      transition_window_ = nullptr;
      return true;
    }
    const BOOL cloak = FALSE;
    const bool revealed = SUCCEEDED(DwmSetWindowAttribute(
        window, DWMWA_CLOAK, &cloak, sizeof(cloak)));
    if (!revealed) return false;
    transition_window_ = nullptr;
    const bool restore_foreground = transition_was_foreground_;
    const HWND expected_foreground = transition_foreground_;
    transition_was_foreground_ = false;
    transition_foreground_ = nullptr;
    const HWND foreground = GetForegroundWindow();
    // Restore activation if it stayed where cloaking left it. A different
    // foreground window means the user switched away during the transition.
    if (restore_foreground &&
        (!foreground || foreground == expected_foreground)) {
      SetForegroundWindow(window);
    }
    return UpdatePresentation(window, GetForegroundWindow() == window);
  }

  flutter::PluginRegistrarWindows* registrar_;
  flutter::FlutterViewController* controller_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
  int display_delegate_ = -1;
  HMONITOR display_monitor_ = nullptr;
  std::optional<double> display_rate_;
  bool display_rate_cached_ = false;
  bool frameless_video_ = false;
  bool fullscreen_ = false;
  bool always_on_top_ = false;
  bool updating_presentation_ = false;
  Microsoft::WRL::ComPtr<ITaskbarList2> taskbar_;
  HWND transition_window_ = nullptr;
  bool transition_was_foreground_ = false;
  HWND transition_foreground_ = nullptr;
  ULONGLONG transition_deadline_ = 0;
  std::shared_ptr<int> transition_ticket_;
  std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
      transition_result_;
};

void RegisterWindowFramePlugin(
    flutter::PluginRegistry* registry,
    flutter::FlutterViewController* controller = nullptr) {
  auto* registrar = flutter::PluginRegistrarManager::GetInstance()
                        ->GetRegistrar<flutter::PluginRegistrarWindows>(
                            registry->GetRegistrarForPlugin(
                                "PlaybackWindowFramePlugin"));
  registrar->AddPlugin(
      std::make_unique<PlaybackWindowFramePlugin>(registrar, controller));
}
}  // namespace

// Reuse Flutter's generated list, including future application plugins. Headers
// above keep the C API declaration intact; only the registration call is skipped.
#define RegisterPlugins RegisterGeneratedMainPlugins
#define MediaKitVideoPluginCApiRegisterWithRegistrar SkipMainVideoRegistration
#include "../flutter/generated_plugin_registrant.cc"
#undef MediaKitVideoPluginCApiRegisterWithRegistrar
#undef RegisterPlugins

void RegisterMainPlugins(flutter::PluginRegistry* registry) {
  RegisterGeneratedMainPlugins(registry);
  RegisterWindowFramePlugin(registry);
}

// Keep credentials, app links, notifications and taskbar services in the main
// engine. desktop_multi_window registers its child channel after this callback.
void RegisterPlaybackPlugins(flutter::FlutterViewController* controller) {
  auto* registry = controller->engine();
  MediaKitLibsWindowsVideoPluginCApiRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("MediaKitLibsWindowsVideoPluginCApi"));
  MediaKitVideoPluginCApiRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("MediaKitVideoPluginCApi"));
  WindowManagerPluginRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("WindowManagerPlugin"));
  RegisterWindowFramePlugin(registry, controller);
  ScreenRetrieverWindowsPluginCApiRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("ScreenRetrieverWindowsPluginCApi"));
  FileSelectorWindowsRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("FileSelectorWindows"));
  UrlLauncherWindowsRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("UrlLauncherWindows"));
  IrondashEngineContextPluginCApiRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("IrondashEngineContextPluginCApi"));
  SuperNativeExtensionsPluginCApiRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("SuperNativeExtensionsPluginCApi"));
}
