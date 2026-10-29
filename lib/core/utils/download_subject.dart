// Dart imports:
import 'dart:io';

// Package imports:
import 'package:path/path.dart' as path;

/// 仅使用明确关联或唯一的 BMF 目录匹配，不根据文件名猜测条目。
/// 手动标记只控制下载完成后的文件跟踪，不影响条目关联。
int? findDownloadSubject({
  required String savePath,
  int? linkedSubject,
  required Iterable<({int subject, String? directory})> directories,
}) {
  if (linkedSubject != null && linkedSubject > 0) return linkedSubject;
  if (savePath.isEmpty) return null;
  String normalize(String value) =>
      path.normalize(Platform.isWindows ? value.replaceAll('/', '\\') : value);
  var target = normalize(savePath);
  var subjects = <int>{};
  for (var entry in directories) {
    var directory = entry.directory;
    if (entry.subject <= 0 || directory == null || directory.isEmpty) continue;
    if (path.equals(normalize(directory), target)) {
      subjects.add(entry.subject);
    }
  }
  return subjects.length == 1 ? subjects.single : null;
}
