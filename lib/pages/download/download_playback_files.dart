// Dart imports:
import 'dart:io';

// Package imports:
import 'package:path/path.dart' as path;

// Project imports:
import '../../core/errors/playback_unavailable.dart';
import '../../core/services/bt_engine/protocol.dart';
import '../../core/utils/playback_paths.dart';
import '../../models/playback/playback_item.dart';

String? downloadPlaybackBlockedReason(BtTaskSnapshot task) {
  if (task.manual && task.state == 'completed' && task.sourceKind != 'http') {
    return '已归档的手动种子任务不再跟踪文件';
  }
  if (task.state == 'checking') return '请等待文件校验完成';
  if (task.state == 'metadata') return '请等待下载任务获取文件信息';
  if (task.downloadedBytes <= 0) return '视频下载完成后即可播放';
  return null;
}

/// Only inspect this task's files, including pages beyond the first window.
/// Disk allocation alone never counts as a completed download.
Future<List<PlaybackItem>> loadDownloadPlaybackFiles({
  required BtTaskSnapshot task,
  required Future<BtTaskFilesResult> Function(int offset) readPage,
  int? subject,
}) async {
  var blocked = downloadPlaybackBlockedReason(task);
  if (blocked != null) throw PlaybackUnavailable(blocked);
  var files = <BtTaskFileDetail>[];
  var offset = 0;
  while (true) {
    var page = await readPage(offset);
    files.addAll(page.files);
    if (!page.truncated) break;
    var next = page.nextOffset;
    if (next == null || next <= offset) {
      throw const PlaybackUnavailable('下载文件列表尚未就绪，请稍后重试');
    }
    offset = next;
  }
  if (files.isEmpty) {
    throw const PlaybackUnavailable('请等待下载任务获取文件信息');
  }
  var videos = files.where(
    (file) => !file.isPadding && PlaybackPaths.isVideo(file.path),
  );
  if (videos.isEmpty) {
    throw const PlaybackUnavailable('此任务中没有支持的视频文件');
  }
  var completed = videos.where(
    (file) =>
        !file.isSkipped && file.size > 0 && file.completedBytes >= file.size,
  );
  if (completed.isEmpty) {
    throw const PlaybackUnavailable('暂无已下载完成的视频，请稍后重试');
  }
  var items = <PlaybackItem>[];
  for (var file in completed) {
    var local = PlaybackPaths.resolveTaskPath(task.savePath, file.path);
    var stat = await File(local).stat();
    if (stat.type != FileSystemEntityType.file || stat.size < file.size) {
      continue;
    }
    items.add(
      PlaybackItem(
        filePath: local,
        title: path.basename(local),
        subject: subject,
        sizeBytes: stat.size,
      ),
    );
  }
  if (items.isEmpty) {
    throw const PlaybackUnavailable('视频文件不存在或不完整，请检查下载目录');
  }
  items.sort((a, b) => PlaybackPaths.episodeCompare(a.filePath, b.filePath));
  return items;
}
