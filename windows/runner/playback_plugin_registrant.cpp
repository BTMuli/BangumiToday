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
#include <flutter_acrylic/flutter_acrylic_plugin.h>
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
  explicit PlaybackWindowFramePlugin(flutter::PluginRegistrarWindows* registrar)
      : registrar_(registrar),
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
          return std::nullopt;
        });
    channel_->SetMethodCallHandler([this](const auto& call, auto result) {
      if (call.method_name() != "setFullscreenFrame" &&
          call.method_name() != "setAlwaysOnTop" &&
          call.method_name() != "getDisplayRefreshRate") {
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
      // the next Flutter frame already has the final viewport.
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
    registrar_->UnregisterTopLevelWindowProcDelegate(display_delegate_);
  }

 private:
  bool UpdatePresentation(HWND window, bool active) {
    // SetWindowPos can synchronously send window messages back to this plugin.
    if (updating_presentation_) return true;
    updating_presentation_ = true;
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
    } else if (fullscreen_ && active) {
      // Reassert on activation: the taskbar and other windows can have risen
      // while another window was in front. An unpinned window only re-enters
      // the top of the ordinary band, so topmost windows still draw above the
      // video; a pinned one keeps the top of the topmost band.
      updated = SetWindowPos(window, topmost ? HWND_TOPMOST : HWND_TOP, 0, 0, 0,
                             0,
                             SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE |
                                 SWP_NOOWNERZORDER) != FALSE;
      if (!updated) order_error = GetLastError();
    }
    HRESULT marked = S_OK;
    if (taskbar_) {
      marked = taskbar_->MarkFullscreenWindow(window, fullscreen_ ? TRUE : FALSE);
    }
    const bool actual_topmost =
        (GetWindowLongPtr(window, GWL_EXSTYLE) & WS_EX_TOPMOST) != 0;
    updated = updated && actual_topmost == topmost;
    char log[256]{};
    _snprintf_s(log, sizeof(log), _TRUNCATE,
                "Playback window order fullscreen=%d active=%d pinned=%d topmost=%d updated=%d error=%lu taskbar=0x%08lx",
                fullscreen_ ? 1 : 0, active ? 1 : 0, always_on_top_ ? 1 : 0,
                actual_topmost ? 1 : 0, updated ? 1 : 0, order_error,
                static_cast<unsigned long>(marked));
    BangumiNativeLog(log, !updated || FAILED(marked));
    updating_presentation_ = false;
    return updated && SUCCEEDED(marked);
  }

  flutter::PluginRegistrarWindows* registrar_;
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
};

void RegisterWindowFramePlugin(flutter::PluginRegistry* registry) {
  auto* registrar = flutter::PluginRegistrarManager::GetInstance()
                        ->GetRegistrar<flutter::PluginRegistrarWindows>(
                            registry->GetRegistrarForPlugin(
                                "PlaybackWindowFramePlugin"));
  registrar->AddPlugin(std::make_unique<PlaybackWindowFramePlugin>(registrar));
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
  // The playback window carries its own Mica/Acrylic material, so this engine
  // needs the acrylic plugin the main engine gets from the generated list.
  FlutterAcrylicPluginRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("FlutterAcrylicPlugin"));
  MediaKitLibsWindowsVideoPluginCApiRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("MediaKitLibsWindowsVideoPluginCApi"));
  MediaKitVideoPluginCApiRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("MediaKitVideoPluginCApi"));
  WindowManagerPluginRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("WindowManagerPlugin"));
  RegisterWindowFramePlugin(registry);
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
