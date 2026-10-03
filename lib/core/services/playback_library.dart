import 'dart:io';

import 'package:path/path.dart' as path;

import '../../models/playback/playback_item.dart';
import 'bt_engine/protocol.dart';

class PlaybackUnavailable implements Exception {
  const PlaybackUnavailable(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Resolves files without treating preallocated disk space as downloaded data.
class PlaybackLibrary {
  PlaybackLibrary({required this.tasks, required this.taskFiles});

  final List<BtTaskSnapshot> Function() tasks;
  final Future<BtTaskFilesResult> Function(String id, int offset) taskFiles;

  static bool isVideo(String value) => const {
    '.mp4',
    '.mkv',
    '.avi',
    '.mov',
    '.webm',
    '.m4v',
    '.ts',
    '.m2ts',
    '.wmv',
    '.flv',
    '.mpg',
    '.mpeg',
    '.ogv',
  }.contains(path.extension(value).toLowerCase());

  static String resolveTaskPath(String root, String relative) {
    // Torrent paths use either separator on Windows.
    var value = Platform.isWindows ? relative.replaceAll('/', '\\') : relative;
    var resolved = path.normalize(path.join(path.absolute(root), value));
    if (path.isAbsolute(value) ||
        !path.isWithin(path.absolute(root), resolved)) {
      throw const PlaybackUnavailable('文件路径超出下载目录');
    }
    return resolved;
  }

  static int naturalCompare(String a, String b) {
    var pattern = RegExp(r'\d+|\D+');
    var left = pattern.allMatches(a.toLowerCase()).map((m) => m[0]!).toList();
    var right = pattern.allMatches(b.toLowerCase()).map((m) => m[0]!).toList();
    for (var i = 0; i < left.length && i < right.length; i++) {
      var ln = int.tryParse(left[i]);
      var rn = int.tryParse(right[i]);
      var comparison = ln != null && rn != null
          ? ln.compareTo(rn)
          : left[i].compareTo(right[i]);
      if (comparison != 0) return comparison;
    }
    var comparison = left.length.compareTo(right.length);
    return comparison != 0 ? comparison : a.compareTo(b);
  }

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

  Future<void> ensureReady(String filePath) => _ensureReady(filePath, {});

  Future<void> _ensureReady(
    String filePath,
    Map<String, List<BtTaskFileDetail>> cachedFiles,
  ) async {
    if (!isVideo(filePath)) {
      throw const PlaybackUnavailable('请选择支持的视频文件');
    }
    var file = File(filePath);
    if (!await file.exists()) {
      throw const PlaybackUnavailable('视频文件不存在，请刷新下载目录');
    }
    var length = await file.length();
    if (length <= 0 || await File('$filePath.aria2').exists()) {
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
        var resolved = resolveTaskPath(task.savePath, entry.path);
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
  }

  Future<List<PlaybackItem>> discover(String dir, {int? subject}) async {
    var directory = Directory(dir);
    if (!await directory.exists()) return [];
    var items = <PlaybackItem>[];
    var cachedFiles = <String, List<BtTaskFileDetail>>{};
    await for (var entity in directory.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is! File || !isVideo(entity.path)) continue;
      try {
        await _ensureReady(entity.path, cachedFiles);
        items.add(
          PlaybackItem(
            filePath: path.absolute(entity.path),
            title: path.basename(entity.path),
            subject: subject,
          ),
        );
      } on PlaybackUnavailable {
        // Pending downloads are omitted until a subsequent refresh.
      }
    }
    items.sort((a, b) => naturalCompare(a.filePath, b.filePath));
    return items;
  }
}
