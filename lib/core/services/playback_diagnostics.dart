// Dart imports:
import 'dart:async';
import 'dart:io';

// Package imports:
import 'package:media_kit/media_kit.dart';

// Project imports:
import '../../tools/log_tool.dart';
import '../utils/playback_health.dart';
import 'native_playback_property_reader.dart';

/// 每个 Player 只有一个采样器，与界面和信息面板的开关无关。
class PlaybackDiagnostics {
  PlaybackDiagnostics(this.player, {required this.context}) {
    BTLogTool.info('创建播放器：${Platform.operatingSystem} $contextText');
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  final Player player;
  final Map<String, Object?> Function() context;
  late final NativePlaybackPropertyReader? _reader =
      player.platform is NativePlayer
      ? NativePlaybackPropertyReader(player.platform as NativePlayer)
      : null;
  final _clock = Stopwatch()..start();
  final _health = PlaybackHealthMonitor();
  late final Timer _timer;
  final _properties = <String, String>{};
  Duration _lastProperties = Duration.zero;
  Duration _lastSnapshot = Duration.zero;
  Duration? _propertiesSampledAt;
  bool _reading = false;
  bool _closed = false;
  bool _active = false;
  int _revision = 0;
  int _outputDrops = 0;
  int _decoderDrops = 0;
  String? _lastLog;
  String? _lastLogLevel;
  Duration _lastLogTime = Duration.zero;
  int _suppressedLogs = 0;
  String? _lastFailure;
  Duration _lastFailureTime = Duration.zero;

  String get _nativeHandle {
    var native = player.platform;
    return native is NativePlayer
        ? native.ctx.address.toRadixString(16).padLeft(16, '0').toUpperCase()
        : 'unknown';
  }

  String get contextText {
    return {
      ...context(),
      'native_handle': _nativeHandle,
      'media_revision': _revision,
    }.toString();
  }

  Future<String> readProperty(String name) {
    if (_closed) return Future.value('');
    return _reader
            ?.read(name)
            .timeout(const Duration(milliseconds: 500), onTimeout: () => '') ??
        Future.value('');
  }

  void opening(String file, Duration resume) {
    _revision++;
    _reader?.invalidate();
    _active = true;
    _health.reset();
    _properties.clear();
    _propertiesSampledAt = null;
    _outputDrops = _decoderDrops = 0;
    _lastProperties = _lastSnapshot = _clock.elapsed;
    BTLogTool.info('打开视频：$file，恢复位置=${resume.inMilliseconds}ms');
  }

  void stopped() {
    if (_closed || !_active) return;
    event('清空当前播放，停止诊断采样');
    _active = false;
    _revision++;
    _reader?.invalidate();
    _properties.clear();
    _propertiesSampledAt = null;
    _health.reset();
    _flushSuppressed();
  }

  void event(String name, {bool error = false}) {
    var message = '$name ${_snapshot()}';
    if (error) {
      BTLogTool.error(message);
    } else {
      BTLogTool.info(message);
    }
  }

  void upscaleEvent(String name) {
    // Step records are numerous. Keep correlation fields here and the full
    // playback/metrics snapshot on apply, output observation and failures.
    if (name.contains(' step=') && !name.contains(' failed ')) {
      BTLogTool.info(
        '$name native_handle=$_nativeHandle media_revision=$_revision',
      );
    } else {
      event(name);
    }
  }

  void log(PlayerLog value) {
    // v 仍供超分检测能力；只落盘 info 以上，避免逐帧调试日志。
    if (!const {'fatal', 'error', 'warn', 'info'}.contains(value.level)) return;
    var message = '[mpv/${value.prefix}/${value.level}] ${value.text.trim()}';
    var now = _clock.elapsed;
    if (message == _lastLog &&
        now - _lastLogTime < const Duration(seconds: 5)) {
      _suppressedLogs++;
      return;
    }
    _flushSuppressed();
    _lastLog = message;
    _lastLogLevel = value.level;
    _lastLogTime = now;
    if (value.level == 'fatal' || value.level == 'error') {
      BTLogTool.error('$message ${_snapshot()}');
    } else if (value.level == 'warn') {
      BTLogTool.warn('$message ${_snapshot()}');
    } else {
      BTLogTool.info(message);
    }
  }

  void failure(String message) {
    var now = _clock.elapsed;
    if (message == _lastFailure &&
        now - _lastFailureTime < const Duration(seconds: 5)) {
      return;
    }
    _lastFailure = message;
    _lastFailureTime = now;
    event('播放器错误：$message', error: true);
  }

  void _flushSuppressed() {
    if (_suppressedLogs == 0) return;
    var message = 'mpv 重复日志合并 $_suppressedLogs 次：$_lastLog';
    if (_lastLogLevel == 'info') {
      BTLogTool.info(message);
    } else {
      BTLogTool.warn(message);
    }
    _suppressedLogs = 0;
  }

  String _snapshot() {
    var state = player.state;
    var fps = double.tryParse(_properties['estimated-vf-fps'] ?? '');
    var effectiveFps = fps == null ? null : fps * state.rate;
    var budget =
        effectiveFps != null && effectiveFps.isFinite && effectiveFps > 0
        ? (1000 / effectiveFps).toStringAsFixed(2)
        : 'unknown';
    var sampledAt = _propertiesSampledAt;
    var age = sampledAt == null
        ? 'unknown'
        : '${(_clock.elapsed - sampledAt).inMilliseconds}';
    return 'position=${state.position.inMilliseconds}ms '
        'duration=${state.duration.inMilliseconds}ms '
        'playing=${state.playing} buffering=${state.buffering} '
        'completed=${state.completed} rate=${state.rate} '
        'frame_budget_ms=$budget metrics_age_ms=$age '
        'video=${state.videoParams} metrics=$_properties $contextText';
  }

  void _tick() {
    if (_closed || !_active) return;
    var now = _clock.elapsed;
    var state = player.state;
    for (var event in _health.sample(
      now: now,
      position: state.position,
      playing: state.playing,
      buffering: state.buffering,
      active: !state.completed,
    )) {
      BTLogTool.warn('$event ${_snapshot()}');
    }
    if (now - _lastProperties >= const Duration(seconds: 5)) {
      _lastProperties = now;
      unawaited(_readProperties());
    }
    if (now - _lastSnapshot >= const Duration(seconds: 15)) {
      _lastSnapshot = now;
      BTLogTool.info('播放状态 ${_snapshot()}');
      _flushSuppressed();
    }
  }

  Future<void> _readProperties() async {
    var native = player.platform;
    if (_closed || _reading || native is! NativePlayer || native.disposed) {
      return;
    }
    _reading = true;
    var revision = _revision;
    var started = _clock.elapsed;
    String? property;
    String? slowestProperty;
    var slowest = Duration.zero;
    var values = <String, String>{};
    try {
      for (var name in const [
        'mpv-version',
        'hwdec-current',
        'current-vo',
        'current-ao',
        'current-tracks/video/codec',
        'estimated-vf-fps',
        'frame-drop-count',
        'decoder-frame-drop-count',
        'avsync',
        'demuxer-cache-duration',
      ]) {
        if (_closed || revision != _revision || native.disposed) return;
        property = name;
        var propertyStarted = _clock.elapsed;
        values[name] = await readProperty(name);
        var elapsed = _clock.elapsed - propertyStarted;
        if (elapsed > slowest) {
          slowest = elapsed;
          slowestProperty = name;
        }
      }
      if (_closed || revision != _revision) return;
      _properties
        ..clear()
        ..addAll(values);
      _propertiesSampledAt = _clock.elapsed;
      var output = int.tryParse(_properties['frame-drop-count'] ?? '') ?? 0;
      var decoder =
          int.tryParse(_properties['decoder-frame-drop-count'] ?? '') ?? 0;
      if (output > _outputDrops || decoder > _decoderDrops) {
        BTLogTool.warn(
          '播放掉帧：output=$output (previous=$_outputDrops) '
          'decoder=$decoder (previous=$_decoderDrops) ${_snapshot()}',
        );
      }
      _outputDrops = output;
      _decoderDrops = decoder;
    } catch (error, stackTrace) {
      if (!_closed && revision == _revision) {
        BTLogTool.warn([
          '读取播放诊断失败：property=$property error=$error $contextText',
          stackTrace.toString(),
        ]);
      }
    } finally {
      var elapsed = (_clock.elapsed - started).inMilliseconds;
      if (!_closed && revision == _revision && elapsed >= 200) {
        BTLogTool.warn(
          '读取播放诊断耗时 ${elapsed}ms '
          'slowest_property=$slowestProperty '
          'slowest_ms=${slowest.inMilliseconds} ${_snapshot()}',
        );
      }
      _reading = false;
    }
  }

  void close() {
    if (_closed) return;
    event('停止播放诊断');
    _closed = true;
    _revision++;
    _timer.cancel();
    unawaited(_reader?.close());
    _flushSuppressed();
    _clock.stop();
  }
}
