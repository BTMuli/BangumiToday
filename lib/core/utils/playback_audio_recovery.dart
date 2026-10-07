// Project imports:
import '../../models/playback/playback_hires.dart';

/// Bounds asynchronous audio reopening using the player's monotonic clock.
class PlaybackAudioRecovery {
  Duration? _configuredAt;
  Duration? _waitingSince;

  void configured(Duration now) {
    _configuredAt = _waitingSince = now;
  }

  void reset() {
    _configuredAt = _waitingSince = null;
  }

  ({bool retry, String? failure}) check(
    Duration now,
    PlaybackHiResState state,
  ) {
    if (!state.configured) {
      reset();
      return (retry: false, failure: null);
    }
    var configuredAt = _configuredAt ??= now;
    if (now - configuredAt < const Duration(milliseconds: 900)) {
      return (retry: true, failure: null);
    }
    var mismatch = state.deviceMismatch;
    if (mismatch == null) {
      _waitingSince = null;
      return (retry: false, failure: null);
    }
    var output = state.output;
    var awaitingOutput =
        state.source == null ||
        output == null ||
        output.sampleRate <= 0 ||
        (output.driver == 'wasapi' && output.exclusive == null);
    if (awaitingOutput) {
      var since = _waitingSince ??= now;
      if (now - since < const Duration(seconds: 3)) {
        return (retry: true, failure: null);
      }
    }
    return (retry: false, failure: mismatch);
  }
}
