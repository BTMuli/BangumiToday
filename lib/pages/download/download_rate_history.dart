// Dart imports:
import 'dart:collection';

// Flutter imports:
import 'package:flutter/foundation.dart';

typedef DownloadRateSample = ({int download, int upload});

/// 平滑改变纵轴范围；目标中途变化时从当前显示值继续过渡。
class DownloadRateScale {
  static const _duration = Duration(milliseconds: 600);
  var _from = 1024.0;
  var _target = 1024.0;
  var _startedAt = Duration.zero;
  var _initialized = false;

  void update(double target, Duration elapsed) {
    if (!_initialized) {
      _from = _target = target;
      _initialized = true;
      return;
    }
    if (_target == target) return;
    _from = valueAt(elapsed);
    _target = target;
    _startedAt = elapsed;
  }

  double valueAt(Duration elapsed) {
    var progress =
        ((elapsed - _startedAt).inMicroseconds / _duration.inMicroseconds)
            .clamp(0.0, 1.0)
            .toDouble();
    var eased = progress * progress * (3 - 2 * progress);
    return _from + (_target - _from) * eased;
  }
}

class DownloadRateFrame {
  const DownloadRateFrame({
    required this.elapsed,
    required this.tasks,
    required this.total,
  });

  final Duration elapsed;
  final Map<String, DownloadRateSample> tasks;
  final DownloadRateSample total;

  DownloadRateSample ratesFor(List<String>? taskIds) {
    if (taskIds == null) return total;
    var download = 0;
    var upload = 0;
    for (var id in taskIds) {
      var rate = tasks[id];
      download += rate?.download ?? 0;
      upload += rate?.upload ?? 0;
    }
    return (download: download, upload: upload);
  }
}

/// 所有背景共用时间轴，保留范围随最宽的图增长，滚动回收不会丢失任务历史。
class DownloadRateHistory extends ChangeNotifier {
  final _frames = ListQueue<DownloadRateFrame>();
  final _clock = Stopwatch()..start();
  var _retention = const Duration(seconds: 2);
  var _revision = 0;

  Iterable<DownloadRateFrame> get frames => _frames;
  Duration get elapsed => _clock.elapsed;
  int get revision => _revision;

  bool hasActivityFor(List<String>? taskIds) => _frames.any((frame) {
    var rate = frame.ratesFor(taskIds);
    return rate.download != 0 || rate.upload != 0;
  });

  /// 延后一秒显示，让下一采样点从右边界外连续进入，采样更新时不重置位置。
  double scrollSecondsAt(Duration elapsed) {
    if (_frames.isEmpty) return 0;
    return (_frames.last.elapsed + const Duration(seconds: 1) - elapsed)
            .inMicroseconds /
        Duration.microsecondsPerSecond;
  }

  void retainFor(Duration duration) {
    if (duration > _retention) _retention = duration;
  }

  void record(Map<String, DownloadRateSample> rates, Duration elapsed) {
    var download = 0;
    var upload = 0;
    var active = <String, DownloadRateSample>{};
    for (var entry in rates.entries) {
      download += entry.value.download;
      upload += entry.value.upload;
      if (entry.value.download != 0 || entry.value.upload != 0) {
        active[entry.key] = entry.value;
      }
    }
    _frames.add(
      DownloadRateFrame(
        elapsed: elapsed,
        tasks: Map.unmodifiable(active),
        total: (download: download, upload: upload),
      ),
    );
    var cutoff = elapsed - _retention;
    while (_frames.length > 1 && _frames.first.elapsed < cutoff) {
      _frames.removeFirst();
    }
    _revision++;
    notifyListeners();
  }

  @override
  void dispose() {
    _clock.stop();
    super.dispose();
  }
}
