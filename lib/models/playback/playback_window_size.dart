import 'dart:math' as math;

/// Bounds for a borderless video window, in logical pixels. Native resizing
/// applies the same aspect ratio; this handles entering and switching videos.
({double width, double height}) fitPlaybackWindowSize({
  required double width,
  required double height,
  required double aspectRatio,
  required double maxWidth,
  required double maxHeight,
  double minimumShortSide = 180,
}) {
  if ([
    width,
    height,
    aspectRatio,
    maxWidth,
    maxHeight,
    minimumShortSide,
  ].any((value) => !value.isFinite || value <= 0)) {
    throw ArgumentError('窗口尺寸和视频比例必须为有限正数');
  }
  var fittedHeight = math.min(height, width / aspectRatio);
  var fittedWidth = fittedHeight * aspectRatio;
  var scale = minimumShortSide / math.min(fittedWidth, fittedHeight);
  if (scale > 1) {
    fittedWidth *= scale;
    fittedHeight *= scale;
  }
  var limit = math.min(maxWidth / fittedWidth, maxHeight / fittedHeight);
  if (limit < 1) {
    fittedWidth *= limit;
    fittedHeight *= limit;
  }
  return (
    width: math.min(fittedWidth, maxWidth),
    height: math.min(fittedHeight, maxHeight),
  );
}
