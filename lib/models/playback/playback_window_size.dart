// Dart imports:
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

/// Keep the top-left corner when resizing; only move to avoid overflow.
/// The caller fits the window size to the work area before positioning it.
({double left, double top}) positionPlaybackWindow({
  required double left,
  required double top,
  required double width,
  required double height,
  required double workLeft,
  required double workTop,
  required double workWidth,
  required double workHeight,
  bool center = false,
}) {
  if ([left, top, workLeft, workTop].any((value) => !value.isFinite) ||
      [
        width,
        height,
        workWidth,
        workHeight,
      ].any((value) => !value.isFinite || value <= 0)) {
    throw ArgumentError('窗口位置必须有限，尺寸必须为有限正数');
  }
  var horizontal = math.max(0.0, workWidth - width);
  var vertical = math.max(0.0, workHeight - height);
  return (
    left: (center ? workLeft + horizontal / 2 : left).clamp(
      workLeft,
      workLeft + horizontal,
    ),
    top: (center ? workTop + vertical / 2 : top).clamp(
      workTop,
      workTop + vertical,
    ),
  );
}
