// Project imports:
import 'download_file_pager.dart';

/// 根据相邻文件快照估算下载速度；首次采样或文件窗口变化时等待下一次刷新。
class DownloadFileRates {
  DownloadFilePage? _previous;
  Duration? _sampledAt;

  void reset() {
    _previous = null;
    _sampledAt = null;
  }

  Map<int, int?> sample(
    DownloadFilePage page, {
    required Duration sampledAt,
    required bool downloading,
  }) {
    if (!downloading) {
      reset();
      return {for (var index in page.indices) index: 0};
    }
    var previous = _previous;
    var elapsed = _sampledAt == null
        ? 0
        : (sampledAt - _sampledAt!).inMicroseconds;
    _previous = page;
    _sampledAt = sampledAt;
    var oldFiles = {
      if (previous != null)
        for (var i = 0; i < previous.files.length; i++)
          previous.indices[i]: previous.files[i],
    };
    var rates = <int, int?>{};
    for (var i = 0; i < page.files.length; i++) {
      var index = page.indices[i];
      var file = page.files[i];
      var old = oldFiles[index];
      if (file.isSkipped ||
          file.isPadding ||
          (file.size > 0 && file.completedBytes >= file.size)) {
        rates[index] = 0;
      } else if (elapsed <= 0 ||
          old == null ||
          old.path != file.path ||
          old.size != file.size ||
          old.isSkipped ||
          file.completedBytes < old.completedBytes) {
        rates[index] = null;
      } else {
        rates[index] =
            (file.completedBytes - old.completedBytes) *
            Duration.microsecondsPerSecond ~/
            elapsed;
      }
    }
    return rates;
  }
}
