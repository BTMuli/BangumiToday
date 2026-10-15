// Dart imports:
import 'dart:async';
import 'dart:io';

// Flutter imports:
import 'package:flutter/services.dart';

// Package imports:
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:path/path.dart' as path;

// Project imports:
import '../../domain/repositories/playback_settings.dart';
import '../../models/playback/playback_janai_benchmark.dart';
import '../../models/playback/playback_upscale.dart';
import '../../tools/log_tool.dart';
import 'native_playback_upscale_backend.dart';
import 'playback_assets.dart';
import 'playback_diagnostics.dart';
import 'playback_janai_benchmarks.dart';
import 'playback_janai_video_source.dart';
import 'playback_tensorrt_gpu.dart';
import 'playback_tensorrt_resources.dart';
import 'playback_upscaler.dart';

/// Owns upscale preferences and lazily loaded inference/benchmark resources.
/// Per-Player filters stay with the Store's media lifecycle.
class PlaybackUpscaleController {
  PlaybackUpscaleController({
    required this.settingsStore,
    required this.readUpscaler,
    required this.isClosed,
    required this.onChanged,
  });

  final PlaybackSettingsStore settingsStore;
  final PlaybackUpscaler? Function() readUpscaler;
  final bool Function() isClosed;
  final void Function() onChanged;
  PlaybackUpscaleMode _mode = PlaybackUpscaleMode.off;
  bool _tensorRtEnabled = false;

  PlaybackUpscaleMode get selectedMode => readUpscaler()?.selectedMode ?? _mode;
  PlaybackUpscaleMode get preferredMode => _mode;
  bool get tensorRtEnabled => _tensorRtEnabled && tensorRtResources.canEnable;

  PlaybackTensorRtResources? _tensorRtResources;
  PlaybackTensorRtResources get tensorRtResources =>
      _tensorRtResources ??= PlaybackTensorRtResources(onChanged: onChanged);

  PlaybackJanaiBenchmarks? _janaiBenchmarks;
  PlaybackJanaiBenchmarks get janaiBenchmarks =>
      _janaiBenchmarks ??= PlaybackJanaiBenchmarks(
        directory: tensorRtResources.dataDirectory,
        onChanged: onChanged,
        loadBundled: () =>
            rootBundle.loadString('assets/benchmarks/animejanai.json'),
      );

  /// Use the actual renderer's adapter, not the first detected CUDA device.
  PlaybackJanaiRecommendation recommendation({
    required PlayerState? state,
    required PlaybackJanaiVideoParameters? source,
  }) {
    var catalog = janaiBenchmarks.catalog;
    if (catalog == null) {
      return PlaybackJanaiRecommendation(
        janaiBenchmarks.error ?? '正在读取 benchmark',
      );
    }
    var native = readUpscaler()?.janaiStatus;
    var gpu = native?.gpuName ?? '';
    if (gpu.isEmpty) {
      gpu = PlaybackJanaiBenchmarkCatalog.rendererGpu(
        readUpscaler()?.renderer ?? '',
      );
    }
    var detected = tensorRtResources.gpu;
    var supported = native != null && native.gpuName.isNotEmpty
        ? native.gpuVendor == 0x10de &&
              PlaybackTensorRtGpu(
                name: native.gpuName,
                sm: native.gpuSm,
                driver: native.gpuDriver,
              ).supported
        : gpu.isEmpty ||
              (detected?.supported == true &&
                  PlaybackJanaiBenchmarkCatalog.gpuKey(gpu) ==
                      PlaybackJanaiBenchmarkCatalog.gpuKey(detected!.name));
    var trackId = source?.trackId ?? state?.track.video.id;
    var track = state?.tracks.video
        .where(
          (track) =>
              track.id == trackId && track.id != 'auto' && track.id != 'no',
        )
        .firstOrNull;
    if (track == null &&
        state?.track.video.id == trackId &&
        trackId != 'auto' &&
        trackId != 'no') {
      track = state?.track.video;
    }
    return catalog.recommend(
      gpu: gpu,
      supported: supported,
      width: source?.width ?? track?.w ?? 0,
      height: source?.height ?? track?.h ?? 0,
      fps: source?.fps ?? track?.fps ?? 0,
      rate: state?.rate ?? 1,
    );
  }

  Future<void> downloadTensorRt() async {
    if (isClosed() || !Platform.isWindows) return;
    await tensorRtResources.initialize();
    if (isClosed()) return;
    var installed = await tensorRtResources.install();
    // Use the current preference and media generation after installation.
    if (installed && !isClosed() && _tensorRtEnabled) {
      readUpscaler()?.inferencePreferenceChanged();
      onChanged();
    }
  }

  Future<void> cancelTensorRt(
    Future<void> Function(PlaybackUpscaleMode) setMode,
  ) async {
    if (tensorRtResources.busy) {
      tensorRtResources.cancel();
    } else {
      tensorRtResources.requestBuildCancellation();
      readUpscaler()?.cancelInferenceBuild();
      try {
        await setMode(PlaybackUpscaleMode.off);
        if (readUpscaler() == null) tensorRtResources.observe(null);
      } catch (_) {
        tensorRtResources.clearBuildCancellation();
        rethrow;
      }
    }
  }

  Future<void> retryTensorRt() async {
    if (tensorRtEnabled) {
      readUpscaler()?.inferencePreferenceChanged();
    }
  }

  Future<void> setUpscaleMode(PlaybackUpscaleMode mode) async {
    if (isClosed() ||
        (_mode == mode && selectedMode == mode) ||
        !Platform.isWindows) {
      return;
    }
    if (mode.isJanai && !tensorRtEnabled) return;
    await settingsStore.write('playbackUpscaleMode', mode.name);
    if (isClosed()) return;
    _mode = mode;
    readUpscaler()?.preferences(_mode);
    onChanged();
  }

  Future<void> setTensorRtEnabled(bool enabled) async {
    if (isClosed() || !Platform.isWindows || _tensorRtEnabled == enabled) {
      return;
    }
    if (enabled && !tensorRtResources.canEnable) return;
    await settingsStore.write('playbackTensorRTEnabled', enabled.toString());
    if (isClosed()) return;
    _tensorRtEnabled = enabled;
    if (!enabled && _mode.isJanai) {
      _mode = PlaybackUpscaleMode.off;
      readUpscaler()?.preferences(_mode);
    }
    readUpscaler()?.inferencePreferenceChanged();
    onChanged();
  }

  Future<void> initializeResources() async {
    await tensorRtResources.initialize();
    unawaited(janaiBenchmarks.initialize());
  }

  Future<void> loadPreferences() async {
    _mode = PlaybackUpscaleMode.parse(
      await settingsStore.read('playbackUpscaleMode'),
    );
    _tensorRtEnabled =
        await settingsStore.read('playbackTensorRTEnabled') == 'true' &&
        tensorRtResources.canEnable;
    if (_mode.isJanai && !_tensorRtEnabled) {
      _mode = PlaybackUpscaleMode.off;
    }
  }

  PlaybackUpscaler createUpscaler(
    Player player,
    VideoController video,
    PlaybackDiagnostics diagnostics,
  ) {
    var assets = PlaybackAnime4kAssets(
      path.join(
        PlaybackAssets.directory(
          executable: Platform.resolvedExecutable,
          operatingSystem: Platform.operatingSystem,
        ),
        'shaders',
        'anime4k',
        'v4.0.1',
      ),
    );
    return PlaybackUpscaler(
        backend: NativePlaybackUpscaleBackend(
          player,
          video,
          tensorRtEnabled: () => tensorRtEnabled,
          tensorRtResources: tensorRtResources,
        ),
        loadShaders: assets.load,
        onChanged: onChanged,
        onError: (error) => BTLogTool.warn('视频超分：$error'),
        onDiagnostics: diagnostics.upscaleEvent,
      )
      ..preferences(_mode)
      ..playbackState(
        playing: player.state.playing,
        buffering: player.state.buffering,
      )
      ..playbackRate(player.state.rate);
  }

  void dispose() {
    _janaiBenchmarks?.dispose();
    _tensorRtResources?.dispose();
  }
}
