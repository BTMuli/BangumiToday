/// 只使用单调时间和播放状态；暂停、切集、正常结束不会被判为卡顿。
class PlaybackHealthMonitor {
  Duration? _lastSample;
  Duration? _unchangedSince;
  Duration? _bufferingSince;
  Duration? _lastWarning;
  Duration? _position;
  bool _stalled = false;

  void reset() {
    _lastSample = null;
    _unchangedSince = null;
    _bufferingSince = null;
    _lastWarning = null;
    _position = null;
    _stalled = false;
  }

  List<String> sample({
    required Duration now,
    required Duration position,
    required bool playing,
    required bool buffering,
    required bool active,
  }) {
    var events = <String>[];
    var previousSample = _lastSample;
    _lastSample = now;
    if (active &&
        previousSample != null &&
        now - previousSample >= const Duration(seconds: 3)) {
      events.add('播放器事件循环延迟 ${(now - previousSample).inMilliseconds}ms');
    }
    if (!active || (!playing && !buffering)) {
      _unchangedSince = null;
      _bufferingSince = null;
      _lastWarning = null;
      _position = position;
      _stalled = false;
      return events;
    }
    if (buffering) {
      _bufferingSince ??= now;
    } else {
      _bufferingSince = null;
    }
    var progressed = _position != position;
    _position = position;
    if (progressed || _unchangedSince == null) _unchangedSince = now;
    var since = _bufferingSince ?? _unchangedSince!;
    var stalled = now - since >= const Duration(seconds: 3);
    if (stalled &&
        (_lastWarning == null ||
            now - _lastWarning! >= const Duration(seconds: 15))) {
      events.add(
        '${buffering ? '持续缓冲' : '播放位置停滞'} '
        '${(now - since).inMilliseconds}ms',
      );
      _lastWarning = now;
    }
    if (_stalled && !stalled) {
      events.add('播放已恢复');
      _lastWarning = null;
    }
    _stalled = stalled;
    return events;
  }
}
