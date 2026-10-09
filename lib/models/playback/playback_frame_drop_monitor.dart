/// Evaluates sustained rendering drops using monotonic, speed-aware windows.
class PlaybackFrameDropMonitor {
  static const _recoveryGrace = Duration(seconds: 4);
  static const _maximumSampleGap = Duration(seconds: 6);
  double _rate = 1;
  double get rate => _rate;
  Duration _eligibleAt = Duration.zero;
  ({num dropped, num frame, num position, Duration elapsed})? _baseline;
  int _windows = 0;

  bool speed(double value, Duration elapsed) {
    if (!value.isFinite || value <= 0 || value == _rate) return false;
    _rate = value;
    restart(elapsed);
    return true;
  }

  /// Pause, buffering and speed changes start a fresh playback window after
  /// the decoder and renderer have had time to settle.
  void restart(Duration elapsed) {
    _eligibleAt = elapsed + _recoveryGrace;
    reset();
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
    // A suspended event loop cannot provide consecutive playback samples.
    // Real output stalls still accumulate through regular two-second polls.
    if (elapsed - previous.elapsed > _maximumSampleGap) {
      restart(elapsed);
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
    _windows = fraction > 0.01 || starved ? _windows + 1 : 0;
    return _windows >= 3;
  }
}
