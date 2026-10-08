#ifndef RUNNER_PLAYBACK_PLUGIN_REGISTRANT_H_
#define RUNNER_PLAYBACK_PLUGIN_REGISTRANT_H_

#include <flutter/plugin_registry.h>

namespace flutter {
class FlutterViewController;
}

// The main engine owns application services; video belongs to the player engine.
void RegisterMainPlugins(flutter::PluginRegistry* registry);
void RegisterPlaybackPlugins(flutter::FlutterViewController* controller);

#endif  // RUNNER_PLAYBACK_PLUGIN_REGISTRANT_H_
