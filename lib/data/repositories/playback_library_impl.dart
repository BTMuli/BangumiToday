// Dart imports:
import 'dart:io';

// Package imports:
import 'package:path/path.dart' as path;

// Project imports:
import '../../core/errors/playback_unavailable.dart';
import '../../core/services/bt_engine/protocol.dart';
import '../../core/utils/playback_paths.dart';
import '../../domain/repositories/playback_library.dart';
import '../../models/playback/playback_item.dart';

/// 基于下载引擎任务快照的本地资源实现。
///
/// 不把预分配的磁盘空间当作已下载数据：文件必须存在、非空，
/// 且在有对应任务时匹配的文件已完成下载和校验。
class PlaybackLibraryImpl implements PlaybackLibrary {
  PlaybackLibraryImpl({required this.tasks, required this.taskFiles});

  /// 当前引擎任务快照读取器。
  final List<BtTaskSnapshot> Function() tasks;

  /// 任务文件详情分页读取器。
  final Future<BtTaskFilesResult> Function(String id, int offset) taskFiles;

  Future<List<BtTaskFileDetail>> _allFiles(String id) async {
    var result = <BtTaskFileDetail>[];
    var offset = 0;
    while (true) {
      var page = await taskFiles(id, offset);
      result.addAll(page.files);
      if (!page.truncated) return result;
      var next = page.nextOffset;
      if (next == null || next <= offset) {
        throw const PlaybackUnavailable('下载文件列表尚未就绪');
      }
      offset = next;
    }
  }

  @override
  Future<void> ensureReady(String filePath) async {
    await _ensureReady(filePath, {});
  }

  Future<int> _ensureReady(
    String filePath,
    Map<String, List<BtTaskFileDetail>> cachedFiles,
  ) async {
    if (!PlaybackPaths.isVideo(filePath)) {
      throw const PlaybackUnavailable('请选择支持的视频文件');
    }
    var file = File(filePath);
    if (!await file.exists()) {
      throw const PlaybackUnavailable('视频文件不存在，请刷新下载目录');
    }
    var length = await file.length();
    if (length <= 0) {
      throw const PlaybackUnavailable('视频文件尚未下载完成');
    }
    var key = PlaybackItem.pathKey(filePath);
    for (var task in List<BtTaskSnapshot>.of(tasks())) {
      var root = PlaybackItem.pathKey(task.savePath);
      if (!path.isWithin(root, key)) continue;
      var files = cachedFiles[task.id] ??= await _allFiles(task.id);
      if (files.isEmpty) {
        throw const PlaybackUnavailable('等待下载任务的文件信息');
      }
      for (var entry in files) {
        if (entry.path.isEmpty) continue;
        var resolved = PlaybackPaths.resolveTaskPath(task.savePath, entry.path);
        if (PlaybackItem.pathKey(resolved) != key) continue;
        if (entry.isPadding ||
            task.state == 'checking' ||
            entry.isSkipped ||
            entry.size <= 0 ||
            length < entry.size ||
            entry.completedBytes < entry.size) {
          throw const PlaybackUnavailable('视频文件尚未完成下载或校验');
        }
      }
    }
    return length;
  }

  @override
  Future<List<PlaybackItem>> discover(String dir, {int? subject}) async {
    var directory = Directory(dir);
    if (!await directory.exists()) return [];
    var items = <PlaybackItem>[];
    var cachedFiles = <String, List<BtTaskFileDetail>>{};
    await for (var entity in directory.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is! File || !PlaybackPaths.isVideo(entity.path)) continue;
      try {
        var size = await _ensureReady(entity.path, cachedFiles);
        items.add(
          PlaybackItem(
            filePath: path.absolute(entity.path),
            title: path.basename(entity.path),
            subject: subject,
            sizeBytes: size,
          ),
        );
      } on PlaybackUnavailable {
        // Pending downloads are omitted until a subsequent refresh.
      }
    }
    items.sort((a, b) => PlaybackPaths.naturalCompare(a.filePath, b.filePath));
    return items;
  }
}
