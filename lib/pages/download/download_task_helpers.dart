// Project imports:
import '../../core/services/bt_engine/protocol.dart';

enum DownloadTaskSortField {
  defaultOrder('默认排序'),
  downloadRate('下载速度'),
  uploadRate('上传速度'),
  remainingTime('剩余时间');

  const DownloadTaskSortField(this.label);

  final String label;
}

/// Sort a copy of the tasks, preserving their input order for equal values.
List<BtTaskSnapshot> sortDownloadTasks(
  List<BtTaskSnapshot> tasks,
  DownloadTaskSortField field, {
  required bool descending,
}) {
  if (field == DownloadTaskSortField.defaultOrder || tasks.length < 2) {
    return tasks;
  }
  var values = tasks.map((task) {
    return switch (field) {
      DownloadTaskSortField.downloadRate => task.downloadRate,
      DownloadTaskSortField.uploadRate => task.uploadRate,
      DownloadTaskSortField.remainingTime => downloadTaskRemainingSeconds(task),
      DownloadTaskSortField.defaultOrder => null,
    };
  }).toList();
  var order = List.generate(tasks.length, (index) => index);
  order.sort((a, b) {
    var valueA = values[a];
    var valueB = values[b];
    // Unknown remaining times stay last in either direction.
    if (valueA == null && valueB == null) return a.compareTo(b);
    if (valueA == null) return 1;
    if (valueB == null) return -1;
    var comparison = descending
        ? valueB.compareTo(valueA)
        : valueA.compareTo(valueB);
    return comparison == 0 ? a.compareTo(b) : comparison;
  });
  return order.map((index) => tasks[index]).toList();
}

/// Use the same estimate for sorting and display; round up partial seconds.
int? downloadTaskRemainingSeconds(BtTaskSnapshot task) {
  var remainingBytes = task.totalBytes - task.downloadedBytes;
  if (task.state != 'downloading' ||
      task.downloadRate <= 0 ||
      remainingBytes <= 0) {
    return null;
  }
  return (remainingBytes + task.downloadRate - 1) ~/ task.downloadRate;
}

String formatDownloadDuration(int seconds) {
  var duration = Duration(seconds: seconds);
  var days = duration.inDays;
  var hours = duration.inHours;
  var minutes = duration.inMinutes.remainder(60);
  var secs = duration.inSeconds.remainder(60);
  if (days > 0) return '$days 天 ${hours.remainder(24)} 小时';
  if (hours > 0) return '$hours 小时 $minutes 分钟';
  if (minutes > 0) return '$minutes 分钟 $secs 秒';
  return '$secs 秒';
}
