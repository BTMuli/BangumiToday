/// Display dimensions include pixel aspect correction; rotation swaps axes.
double? playbackAspectRatio({
  double? aspect,
  int? width,
  int? height,
  int? rotation,
}) {
  var ratio = aspect;
  if (ratio == null || !ratio.isFinite || ratio <= 0) {
    if (width == null || height == null || width <= 0 || height <= 0) {
      return null;
    }
    ratio = width / height;
  }
  return (rotation ?? 0) % 180 == 90 ? 1 / ratio : ratio;
}

/// Largest surface that fits in the available area without letterboxing.
({double width, double height}) playbackSurfaceSize(
  double width,
  double height,
  double? aspectRatio,
) {
  if (aspectRatio == null || !aspectRatio.isFinite || aspectRatio <= 0) {
    return (width: width, height: height);
  }
  if (width / height > aspectRatio) {
    return (width: height * aspectRatio, height: height);
  }
  return (width: width, height: width / aspectRatio);
}
