#include "playback_plugin_registrant.h"

#include <dwmapi.h>
#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

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

// window_manager owns fullscreen bounds and restoration, but leaves caption
// styles in place. Complete the frame change on this engine's own window.
class PlaybackWindowFramePlugin : public flutter::Plugin {
 public:
  explicit PlaybackWindowFramePlugin(flutter::PluginRegistrarWindows* registrar)
      : registrar_(registrar),
        channel_(std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
            registrar->messenger(), "bangumi_today/playback_window_frame",
            &flutter::StandardMethodCodec::GetInstance())) {
    channel_->SetMethodCallHandler([this](const auto& call, auto result) {
      if (call.method_name() != "setFullscreenFrame") {
        result->NotImplemented();
        return;
      }
      const auto* fullscreen = call.arguments()
                                   ? std::get_if<bool>(call.arguments())
                                   : nullptr;
      if (!fullscreen) {
        result->Error("invalid_argument", "Expected a fullscreen boolean.");
        return;
      }
      auto* view = registrar_->GetView();
      HWND window = view ? GetAncestor(view->GetNativeWindow(), GA_ROOT) : nullptr;
      if (!window || !IsWindow(window)) {
        result->Error("window_unavailable", "Playback window is unavailable.");
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

 private:
  flutter::PluginRegistrarWindows* registrar_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
};
}  // namespace

// Reuse Flutter's generated list, including future application plugins. Headers
// above keep the C API declaration intact; only the registration call is skipped.
#define RegisterPlugins RegisterMainPlugins
#define MediaKitVideoPluginCApiRegisterWithRegistrar SkipMainVideoRegistration
#include "../flutter/generated_plugin_registrant.cc"
#undef MediaKitVideoPluginCApiRegisterWithRegistrar
#undef RegisterPlugins

// Keep credentials, app links, notifications and taskbar services in the main
// engine. desktop_multi_window registers its child channel after this callback.
void RegisterPlaybackPlugins(flutter::PluginRegistry* registry) {
  MediaKitLibsWindowsVideoPluginCApiRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("MediaKitLibsWindowsVideoPluginCApi"));
  MediaKitVideoPluginCApiRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("MediaKitVideoPluginCApi"));
  WindowManagerPluginRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("WindowManagerPlugin"));
  auto* frame_registrar = flutter::PluginRegistrarManager::GetInstance()
                              ->GetRegistrar<flutter::PluginRegistrarWindows>(
                                  registry->GetRegistrarForPlugin(
                                      "PlaybackWindowFramePlugin"));
  frame_registrar->AddPlugin(
      std::make_unique<PlaybackWindowFramePlugin>(frame_registrar));
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
