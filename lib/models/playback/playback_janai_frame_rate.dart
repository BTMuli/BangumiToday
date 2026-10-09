// Dart imports:
import 'dart:math' as math;

/// Selects hardware frames before inference, without changing their PTS.
class PlaybackJanaiFrameRate {
  const PlaybackJanaiFrameRate({
    required this.playbackRate,
    required this.framesPerSecond,
  });

  final double playbackRate;

  /// Retained frames per wall-clock second, after applying playback speed.
  /// Null selects by frame index until the source cadence becomes available.
  final double? framesPerSecond;
  double? get inputFramesPerSecond =>
      framesPerSecond == null ? null : framesPerSecond! / playbackRate;

  /// One frame per media-time bucket avoids drift at fractional playback rates.
  /// Missing PTS passes through; the first backwards timestamp is retained.
  String get graph {
    var input = inputFramesPerSecond;
    if (input == null) {
      var rate = playbackRate.toStringAsPrecision(12);
      // Keep the first frame and one out of every playbackRate input frames,
      // including fractional rates. This also works before PTS/FPS is known.
      return "select='gt(floor(n/$rate),floor((n-1)/$rate))'";
    }
    var frequency = input.toStringAsPrecision(12);
    return "select='isnan(t)+isnan(prev_selected_t)+lt(t,prev_selected_t)+"
        'gt(floor((t-start_t)*$frequency+0.000001),'
        "floor((prev_selected_t-start_t)*$frequency+0.000001))'";
  }

  @override
  bool operator ==(Object other) =>
      other is PlaybackJanaiFrameRate &&
      playbackRate == other.playbackRate &&
      framesPerSecond == other.framesPerSecond;

  @override
  int get hashCode => Object.hash(playbackRate, framesPerSecond);
}

/// Keeps accelerated AI inference at the source's normal wall-clock cadence.
/// Increasing playback speed must not increase the inference workload. GPU
/// capacity alone cannot budget decoding, rendering and window composition.
PlaybackJanaiFrameRate? playbackJanaiFrameRate({
  required double sourceFramesPerSecond,
  required double playbackRate,
  double displayFramesPerSecond = 60,
}) {
  if (!playbackRate.isFinite || playbackRate <= 1) {
    return null;
  }
  if (!sourceFramesPerSecond.isFinite || sourceFramesPerSecond <= 0) {
    return PlaybackJanaiFrameRate(
      playbackRate: playbackRate,
      framesPerSecond: null,
    );
  }
  var display = displayFramesPerSecond.isFinite && displayFramesPerSecond > 0
      ? math.min(displayFramesPerSecond, 60.0)
      : 60.0;
  return PlaybackJanaiFrameRate(
    playbackRate: playbackRate,
    framesPerSecond: math.min(sourceFramesPerSecond, display),
  );
}
