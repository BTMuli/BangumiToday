// Dart imports:
import 'dart:async';

// Package imports:
import 'package:hive_ce/hive_ce.dart';

/// 应用侧的任务条目关联，不属于下载引擎协议。
class DownloadSubjectsStorage {
  Future<Box<int>>? _opening;

  Future<Box<int>> _open() async {
    var opening = _opening ??= Hive.openBox<int>('download_subjects');
    try {
      return await opening;
    } catch (_) {
      if (identical(_opening, opening)) _opening = null;
      rethrow;
    }
  }

  Future<int?> read(String taskId) async => (await _open()).get(taskId);

  Future<void> write(String taskId, int subjectId) async {
    if (subjectId <= 0) return;
    await (await _open()).put(taskId, subjectId);
  }

  Future<void> delete(String taskId) async {
    await (await _open()).delete(taskId);
  }

  Stream<int?> watch(String taskId) async* {
    var box = await _open();
    yield* Stream<int?>.multi((controller) {
      var subscription = box
          .watch(key: taskId)
          .listen(
            (_) => controller.add(box.get(taskId)),
            onError: controller.addError,
            onDone: controller.close,
          );
      controller.onCancel = subscription.cancel;
      controller.add(box.get(taskId));
    });
  }
}

final downloadSubjectsStorage = DownloadSubjectsStorage();
