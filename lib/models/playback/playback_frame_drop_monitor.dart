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
    double? expectedFramesPerSecond,
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
    var current = (
      dropped: dropped,
      frame: frame,
      position: position,
      elapsed: elapsed,
    );
    if (previous == null) {
      _baseline = current;
      return false;
    }
    var wallSeconds =
        (elapsed - previous.elapsed).inMicroseconds /
        Duration.microsecondsPerSecond;
    // A seek jumps beyond the media time expected at this speed. The margin
    // tolerates asynchronous property sampling and decoder timestamp jitter.
    if (wallSeconds <= 0 ||
        position < previous.position ||
        position - previous.position > wallSeconds * _rate + 2 ||
        frame < previous.frame ||
        dropped < previous.dropped) {
      _baseline = current;
      _windows = 0;
      return false;
    }
    // Accumulate a real time window, including intervals with zero successful
    // frames. Moving the baseline on every undersized sample hid severe stalls.
    if (wallSeconds < 2) return false;
    _baseline = current;
    var frames = frame - previous.frame;
    var drops = dropped - previous.dropped;
    var fraction = frames > 0 ? drops / frames : (drops > 0 ? 1.0 : 0.0);
    var expected = expectedFramesPerSecond ?? 0;
    var minimum = expected * 0.25;
    if (minimum > 5) minimum = 5;
    var starved =
        expected.isFinite && expected > 0 && frames / wallSeconds < minimum;
    var windows = (wallSeconds / 2).floor().clamp(1, 3);
    _windows = fraction > 0.01 || starved ? _windows + windows : 0;
    return _windows >= 3;
  }
}
