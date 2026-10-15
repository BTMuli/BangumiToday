// Dart imports:
import 'dart:async';
import 'dart:io';

// Package imports:
import 'package:media_kit/media_kit.dart';

// Project imports:
import '../../domain/repositories/playback_settings.dart';
import '../../models/playback/playback_hires.dart';
import '../../models/playback/playback_item.dart';
import '../utils/playback_audio_recovery.dart';
import 'playback_audio.dart';
import 'playback_audio_metadata.dart';
import 'playback_loudness.dart';

typedef PlaybackAudioSession = ({
  String id,
  PlaybackItem? item,
  bool completed,
});

/// Owns audio preferences, output recovery and per-media metadata.
/// Mutating commands run on the playback session's existing serial queue.
class PlaybackAudioController {
  PlaybackAudioController({
    required this.settingsStore,
    required this.readPlayer,
    required this.readSession,
    required this.isClosed,
    required this.serial,
    required this.onDiagnostic,
    required this.onChanged,
  });

  final PlaybackSettingsStore settingsStore;
  final Player? Function() readPlayer;
  final PlaybackAudioSession Function() readSession;
  final bool Function() isClosed;
  final Future<void> Function(Future<void> Function()) serial;
  final void Function(String) onDiagnostic;
  final void Function() onChanged;

  bool _loudnessEnabled = Platform.isWindows;
  bool _hiResEnabled = false;
  bool _hiResConfigured = false;
  bool _audioExclusiveEnabled = false;
  bool _audioExclusiveConfigured = false;
  PlaybackAudioSource? _audioSource;
  PlaybackAudioOutput? _audioOutput;
  String? _hiResFailure;
  String? _hiResBlockedSource;
  String? _lastAudioSourceKey;
  final _audioClock = Stopwatch()..start();
  final _audioRecovery = PlaybackAudioRecovery();
  Timer? _audioRefreshTimer;
  Timer? _audioWatchdog;
  final _audioMetadata = PlaybackAudioMetadata();
  PlaybackWasapiFormat? _wasapiFormat;

  bool get loudnessEnabled => _loudnessEnabled;
  bool get hiResEnabled => _hiResEnabled;
  bool get audioExclusiveEnabled => _audioExclusiveEnabled;
  bool get canEnableAudioExclusive => PlaybackAudio.supported && _hiResEnabled;
  PlaybackHiResState get hiRes => PlaybackHiResState(
    source: _audioSource,
    output: _audioOutput,
    requested: _hiResEnabled,
    configured: _hiResConfigured,
    exclusiveRequested: _hiResEnabled && _audioExclusiveEnabled,
    supported: PlaybackAudio.supported,
    rate: readPlayer()?.state.rate ?? 1,
    failure: _hiResFailure,
  );
  bool get loudnessActive => _loudnessEnabled && !_hiResConfigured;
  bool get loudnessPausedForHiRes => _hiResConfigured;

  Future<void> setLoudnessEnabled(bool enabled) async {
    if (isClosed() || _loudnessEnabled == enabled || !Platform.isWindows) {
      return;
    }
    var player = readPlayer();
    if (player != null && !_hiResConfigured) {
      await PlaybackLoudness.apply(player, enabled);
    }
    if (isClosed()) return;
    try {
      await settingsStore.write(PlaybackLoudness.settingKey, '$enabled');
    } catch (_) {
      if (!isClosed() && player != null && !_hiResConfigured) {
        await PlaybackLoudness.apply(player, loudnessActive);
      }
      rethrow;
    }
    if (isClosed()) return;
    _loudnessEnabled = enabled;
    onDiagnostic('音量标准化改变：enabled=$enabled');
    onChanged();
  }

  Future<void> setHiResEnabled(bool enabled) async {
    if (isClosed() || _hiResEnabled == enabled) return;
    await settingsStore.write(PlaybackAudio.settingKey, '$enabled');
    if (isClosed()) return;
    _hiResEnabled = enabled;
    _hiResBlockedSource = null;
    _hiResFailure = null;
    await _refreshAudio();
    onDiagnostic('HiRes 偏好改变：enabled=$enabled，${hiRes.status}');
    onChanged();
  }

  Future<void> setAudioTrack(AudioTrack track) async {
    await reset();
    await readPlayer()?.setAudioTrack(track);
    scheduleRefresh();
  }

  Future<void> setAudioExclusiveEnabled(bool enabled) async {
    if (isClosed() ||
        _audioExclusiveEnabled == enabled ||
        (enabled && !canEnableAudioExclusive)) {
      return;
    }
    await settingsStore.write(PlaybackAudio.exclusiveSettingKey, '$enabled');
    if (isClosed()) return;
    _audioExclusiveEnabled = enabled;
    _hiResBlockedSource = null;
    _hiResFailure = null;
    await _refreshAudio();
    onDiagnostic('独占输出偏好改变：enabled=$enabled，${hiRes.status}');
    onChanged();
  }

  void scheduleRefresh({Duration delay = const Duration(milliseconds: 150)}) {
    if (isClosed() ||
        readSession().item == null ||
        _audioRefreshTimer?.isActive == true) {
      return;
    }
    var sessionId = readSession().id;
    _audioRefreshTimer = Timer(delay, () {
      unawaited(
        serial(() async {
          if (readSession().id != sessionId || readSession().item == null) {
            return;
          }
          await _refreshAudio();
        }).catchError((Object _) {}),
      );
    });
  }

  Future<void> _configureHiRes(bool enabled) async {
    var player = readPlayer();
    var exclusive = enabled && _audioExclusiveEnabled;
    if (player == null ||
        (_hiResConfigured == enabled &&
            _audioExclusiveConfigured == exclusive)) {
      return;
    }
    var previous = _hiResConfigured;
    var previousExclusive = _audioExclusiveConfigured;
    // Shared HiRes can keep the current device open when only its filters
    // change. Retain its accepted format unless the access mode changes.
    if (previousExclusive != exclusive) _wasapiFormat = null;
    onDiagnostic('HiRes 输出配置开始：enabled=$enabled，exclusive=$exclusive');
    try {
      if (Platform.isWindows) {
        await PlaybackLoudness.apply(player, _loudnessEnabled && !enabled);
      }
      await PlaybackAudio.apply(player, exclusive);
    } catch (_) {
      if (!isClosed()) {
        await PlaybackAudio.apply(player, previousExclusive);
        if (Platform.isWindows) {
          await PlaybackLoudness.apply(player, _loudnessEnabled && !previous);
        }
      }
      rethrow;
    }
    if (isClosed()) return;
    _hiResConfigured = enabled;
    _audioExclusiveConfigured = exclusive;
    if (enabled) {
      _audioRecovery.configured(_audioClock.elapsed);
      _audioWatchdog ??= Timer.periodic(const Duration(seconds: 5), (_) {
        if (readPlayer()?.state.playing == true && !readSession().completed) {
          scheduleRefresh();
        }
      });
    } else {
      _audioRecovery.reset();
      _audioWatchdog?.cancel();
      _audioWatchdog = null;
    }
    onDiagnostic('HiRes 输出配置完成：enabled=$enabled，exclusive=$exclusive');
  }

  String? _audioSourceKey(PlaybackAudioSource? source) => source == null
      ? null
      : '${source.id}/${source.codec}/${source.sampleRate}/'
            '${source.format}/${source.channels}';

  Future<void> _refreshAudio() async {
    var player = readPlayer();
    if (isClosed() || player == null || readSession().item == null) return;
    var sessionId = readSession().id;
    var before = hiRes.tooltip;
    var params = await PlaybackAudio.read(
      player,
      filePath: readSession().item!.filePath,
      metadata: _audioMetadata,
      deviceFormat: _wasapiFormat,
    );
    if (isClosed() || sessionId != readSession().id) return;
    _audioSource = params.source;
    _audioOutput = params.output;
    var key = _audioSourceKey(params.source) ?? _lastAudioSourceKey;
    _lastAudioSourceKey = key;
    if (_hiResBlockedSource != key) _hiResFailure = null;
    var desired =
        _hiResEnabled &&
        PlaybackAudio.supported &&
        (params.source?.hiRes ?? _hiResConfigured) &&
        (_hiResBlockedSource == null || _hiResBlockedSource != key);
    try {
      await _configureHiRes(desired);
      if (isClosed()) return;
      if (_hiResConfigured) {
        var recovery = _audioRecovery.check(_audioClock.elapsed, hiRes);
        if (recovery.retry) {
          scheduleRefresh(delay: const Duration(milliseconds: 500));
        } else if (recovery.failure != null) {
          _hiResFailure = recovery.failure;
          _hiResBlockedSource = key;
          await _configureHiRes(false);
          if (isClosed()) return;
          await PlaybackAudio.reopenOutput(player);
          onDiagnostic('HiRes 回退共享输出：$_hiResFailure');
          scheduleRefresh(delay: const Duration(milliseconds: 500));
        }
      }
    } catch (failure) {
      _hiResFailure = failure.toString();
      _hiResBlockedSource = key;
      onDiagnostic('HiRes 配置失败：$failure');
    }
    if (before != hiRes.tooltip) onChanged();
  }

  Future<void> reset() async {
    _audioRefreshTimer?.cancel();
    _audioWatchdog?.cancel();
    _audioWatchdog = null;
    _audioRecovery.reset();
    _lastAudioSourceKey = null;
    _audioMetadata.clear();
    _audioSource = null;
    _audioOutput = null;
    _hiResFailure = null;
    _hiResBlockedSource = null;
    await _configureHiRes(false);
    onChanged();
  }

  bool get exclusiveConfigured => _audioExclusiveConfigured;

  Future<void> loadPreferences() async {
    _hiResEnabled =
        await settingsStore.read(PlaybackAudio.settingKey) == 'true';
    _audioExclusiveEnabled =
        await settingsStore.read(PlaybackAudio.exclusiveSettingKey) == 'true';
  }

  Future<void> loadLoudnessPreference() async {
    _loudnessEnabled = PlaybackLoudness.parse(
      await settingsStore.read(PlaybackLoudness.settingKey),
    );
  }

  void log(PlayerLog value) {
    if (value.prefix != 'ao/wasapi') return;
    var format = PlaybackWasapiFormat.parse(value.text);
    if (format == null) return;
    _wasapiFormat = format;
    scheduleRefresh();
  }

  void deviceChanged() {
    _hiResBlockedSource = null;
    _hiResFailure = null;
    scheduleRefresh();
  }

  /// Stop callbacks before the Player is detached or the session closes.
  void releasePlayer() {
    _audioRefreshTimer?.cancel();
    _audioRefreshTimer = null;
    _audioWatchdog?.cancel();
    _audioWatchdog = null;
    _wasapiFormat = null;
  }
}
