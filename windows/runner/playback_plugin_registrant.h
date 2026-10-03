#ifndef RUNNER_PLAYBACK_PLUGIN_REGISTRANT_H_
#define RUNNER_PLAYBACK_PLUGIN_REGISTRANT_H_

#include <flutter/plugin_registry.h>

// The main engine owns application services; video belongs to the player engine.
void RegisterMainPlugins(flutter::PluginRegistry* registry);
void RegisterPlaybackPlugins(flutter::PluginRegistry* registry);

#endif  // RUNNER_PLAYBACK_PLUGIN_REGISTRANT_H_
