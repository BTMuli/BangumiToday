#include "playback_plugin_registrant.h"

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
