// Flutter imports:
import 'package:flutter/foundation.dart';

// Project imports:
import '../../core/services/bt_engine/protocol.dart';

class DownloadTaskGroup {
  DownloadTaskGroup({
    required this.subjectId,
    required List<BtTaskSnapshot> tasks,
  }) : tasks = List.unmodifiable(tasks);

  final int? subjectId;
  final List<BtTaskSnapshot> tasks;

  String get key =>
      subjectId == null ? 'task_${tasks.single.id}' : 'subject_$subjectId';
}

/// Merge linked tasks in their current order; unlinked tasks stay separate.
List<DownloadTaskGroup> groupDownloadTasks(
  List<BtTaskSnapshot> tasks,
  Map<String, int?> subjectIds,
) {
  var groupedTasks = <String, List<BtTaskSnapshot>>{};
  var groupedSubjects = <String, int?>{};
  for (var task in tasks) {
    var id = subjectIds[task.id];
    var subjectId = id != null && id > 0 ? id : null;
    var key = subjectId == null ? 'task_${task.id}' : 'subject_$subjectId';
    (groupedTasks[key] ??= []).add(task);
    groupedSubjects[key] = subjectId;
  }
  return [
    for (var entry in groupedTasks.entries)
      DownloadTaskGroup(
        subjectId: groupedSubjects[entry.key],
        tasks: entry.value,
      ),
  ];
}

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
  var byId = {for (var task in tasks) task.id: task};
  return DownloadTaskSortValues(
    tasks,
    field,
  ).sortedIds(descending: descending).map((id) => byId[id]!).toList();
}

/// 相等性仅包含当前排序字段，上传等无关变化不会重新计算下载速率排序。
class DownloadTaskSortValues {
  DownloadTaskSortValues(
    List<BtTaskSnapshot> tasks,
    DownloadTaskSortField field,
  ) : values = [
        for (var task in tasks)
          (
            task.id,
            switch (field) {
              DownloadTaskSortField.downloadRate => task.downloadRate,
              DownloadTaskSortField.uploadRate => task.uploadRate,
              DownloadTaskSortField.remainingTime =>
                downloadTaskRemainingSeconds(task),
              DownloadTaskSortField.defaultOrder => null,
            },
          ),
      ];

  final List<(String, int?)> values;

  List<String> sortedIds({required bool descending}) {
    var order = List.generate(values.length, (index) => index);
    order.sort((a, b) {
      var valueA = values[a].$2;
      var valueB = values[b].$2;
      // 未知剩余时间在两个方向都保持最后，同值保留默认顺序。
      if (valueA == null && valueB == null) return a.compareTo(b);
      if (valueA == null) return 1;
      if (valueB == null) return -1;
      var comparison = descending
          ? valueB.compareTo(valueA)
          : valueA.compareTo(valueB);
      return comparison == 0 ? a.compareTo(b) : comparison;
    });
    return order.map((index) => values[index].$1).toList();
  }

  @override
  bool operator ==(Object other) =>
      other is DownloadTaskSortValues && listEquals(values, other.values);

  @override
  int get hashCode => Object.hashAll(values);
}

class DownloadTaskOrder {
  DownloadTaskOrder(List<String> ids) : ids = List.unmodifiable(ids);

  final List<String> ids;

  @override
  bool operator ==(Object other) =>
      other is DownloadTaskOrder && listEquals(ids, other.ids);

  @override
  int get hashCode => Object.hashAll(ids);
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
