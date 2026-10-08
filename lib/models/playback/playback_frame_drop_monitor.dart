/// Evaluates sustained rendering drops using monotonic, speed-aware windows.
class PlaybackFrameDropMonitor {
  static const _speedGrace = Duration(seconds: 4);
  double _rate = 1;
  double get rate => _rate;
  Duration _eligibleAt = Duration.zero;
  ({num dropped, num frame, num position, Duration elapsed})? _baseline;
  int _windows = 0;

  bool speed(double value, Duration elapsed) {
    if (!value.isFinite || value <= 0 || value == _rate) return false;
    _rate = value;
    _eligibleAt = elapsed + _speedGrace;
    reset();
    return true;
  }

  void reset() {
    _baseline = null;
    _windows = 0;
  }

  bool observe({
    required num dropped,
    required num frame,
    required num position,
    required Duration elapsed,
  }) {
    if (elapsed < _eligibleAt ||
        !dropped.isFinite ||
        !frame.isFinite ||
        !position.isFinite ||
        dropped < 0 ||
        frame < 0) {
      reset();
      return false;
    }
    var previous = _baseline;
    _baseline = (
      dropped: dropped,
      frame: frame,
      position: position,
      elapsed: elapsed,
    );
    if (previous == null) return false;
    var wallSeconds =
        (elapsed - previous.elapsed).inMicroseconds /
        Duration.microsecondsPerSecond;
    // A seek jumps beyond the media time expected at this speed. The margin
    // tolerates asynchronous property sampling and decoder timestamp jitter.
    if (wallSeconds <= 0 ||
        position <= previous.position ||
        position - previous.position > wallSeconds * _rate + 2 ||
        frame - previous.frame < 10 ||
        dropped < previous.dropped) {
      _windows = 0;
      return false;
    }
    var fraction = (dropped - previous.dropped) / (frame - previous.frame);
    _windows = fraction > 0.01 ? _windows + 1 : 0;
    return _windows >= 3;
  }
}
