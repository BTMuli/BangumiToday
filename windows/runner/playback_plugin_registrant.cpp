#include "playback_plugin_registrant.h"

#include <dwmapi.h>
#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

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

// window_manager owns fullscreen bounds and restoration, but leaves caption
// styles in place. Complete the frame change on this engine's own window.
class PlaybackWindowFramePlugin : public flutter::Plugin {
 public:
  explicit PlaybackWindowFramePlugin(flutter::PluginRegistrarWindows* registrar)
      : registrar_(registrar),
        channel_(std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
            registrar->messenger(), "bangumi_today/playback_window_frame",
            &flutter::StandardMethodCodec::GetInstance())) {
    display_delegate_ = registrar_->RegisterTopLevelWindowProcDelegate(
        [this](HWND, UINT message, WPARAM, LPARAM) -> std::optional<LRESULT> {
          if (message == WM_DISPLAYCHANGE || message == WM_SETTINGCHANGE) {
            display_rate_cached_ = false;
          }
          return std::nullopt;
        });
    channel_->SetMethodCallHandler([this](const auto& call, auto result) {
      if (call.method_name() != "setFullscreenFrame" &&
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
      if (*fullscreen) {
        auto style = GetWindowLongPtr(window, GWL_STYLE);
        // Also clear WS_MAXIMIZE so NCCALCSIZE does not compensate for the
        // maximized resize borders when the window fills the entire monitor.
        SetLastError(ERROR_SUCCESS);
        if (!SetWindowLongPtr(window, GWL_STYLE,
                              style & ~(WS_OVERLAPPEDWINDOW | WS_MAXIMIZE)) &&
            GetLastError() != ERROR_SUCCESS) {
          result->Error("frame_update_failed", "Could not remove window styles.");
          return;
        }
      }
      // Numeric values keep older Windows SDK headers supported. Windows 10
      // ignores these unsupported DWM attributes; removing the styles suffices.
      constexpr DWORD kCornerPreference = 33;  // DWMWA_WINDOW_CORNER_PREFERENCE
      constexpr DWORD kBorderColor = 34;       // DWMWA_BORDER_COLOR
      const DWORD corners = *fullscreen ? 1 : 2;  // DONOTROUND / ROUND
      const COLORREF border = *fullscreen ? 0xfffffffe : 0xffffffff;
      DwmSetWindowAttribute(window, kCornerPreference, &corners, sizeof(corners));
      DwmSetWindowAttribute(window, kBorderColor, &border, sizeof(border));
      // On exit, window_manager has already restored the saved native styles.
      if (!SetWindowPos(window, nullptr, 0, 0, 0, 0,
                        SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER |
                            SWP_NOACTIVATE | SWP_FRAMECHANGED)) {
        result->Error("frame_update_failed", "Could not refresh the window frame.");
        return;
      }
      result->Success();
    });
  }

  ~PlaybackWindowFramePlugin() override {
    registrar_->UnregisterTopLevelWindowProcDelegate(display_delegate_);
  }

 private:
  flutter::PluginRegistrarWindows* registrar_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
  int display_delegate_ = -1;
  HMONITOR display_monitor_ = nullptr;
  std::optional<double> display_rate_;
  bool display_rate_cached_ = false;
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
void RegisterPlaybackPlugins(flutter::PluginRegistry* registry) {
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
