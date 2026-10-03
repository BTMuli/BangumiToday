enum PlaybackFit {
  stretch('拉伸', '填满容器，不保持视频比例'),
  tile('平铺', '保持比例并裁切画面，填满容器'),
  fit('适配', '保持比例与完整画面，容器跟随视频调整');

  const PlaybackFit(this.label, this.description);

  final String label;
  final String description;

  static PlaybackFit parse(String? value) =>
      values.where((mode) => mode.name == value).firstOrNull ?? fit;
}

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
