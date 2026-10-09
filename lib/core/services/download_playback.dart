// Dart imports:
import 'dart:io';

// Project imports:
import '../errors/playback_unavailable.dart';
import '../utils/playback_paths.dart';
import 'bt_engine/protocol.dart';

/// 从指定任务中选择首个已完成且仍在磁盘上的视频，不扫描其他下载任务。
Future<String> firstCompletedDownloadVideo({
  required BtTaskSnapshot task,
  required Future<BtTaskFilesResult> Function(int offset) readFiles,
}) async {
  if (task.state == 'checking') {
    throw const PlaybackUnavailable('下载任务正在校验，请稍后播放');
  }
  var files = <BtTaskFileDetail>[];
  var offset = 0;
  while (true) {
    var page = await readFiles(offset);
    files.addAll(
      page.files.where(
        (file) =>
            !file.isPadding &&
            !file.isSkipped &&
            file.size > 0 &&
            file.completedBytes >= file.size &&
            PlaybackPaths.isVideo(file.path),
      ),
    );
    if (!page.truncated) break;
    var next = page.nextOffset;
    if (next == null || next <= offset) {
      throw const PlaybackUnavailable('下载文件列表尚未就绪');
    }
    offset = next;
  }
  files.sort((a, b) => PlaybackPaths.episodeCompare(a.path, b.path));
  for (var file in files) {
    var filePath = PlaybackPaths.resolveTaskPath(task.savePath, file.path);
    var stat = await File(filePath).stat();
    if (stat.type == FileSystemEntityType.file && stat.size >= file.size) {
      return filePath;
    }
  }
  throw const PlaybackUnavailable('该下载任务没有可播放的已完成视频');
}
