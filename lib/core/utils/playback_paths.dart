// Dart imports:
import 'dart:io';

// Package imports:
import 'package:path/path.dart' as path;

// Project imports:
import '../errors/playback_unavailable.dart';

/// 播放资源的纯路径与命名规则。
///
/// 不依赖存储或引擎，供资源校验、文件列表与下载详情共用；需要表或引擎的
/// 能力放在 `lib/data/repositories/` 的实现里。
class PlaybackPaths {
  const PlaybackPaths._();

  static const Set<String> videoExtensions = {
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
  };

  static bool isVideo(String value) =>
      videoExtensions.contains(path.extension(value).toLowerCase());

  /// 按拖入顺序选择首个本地视频，保留 URI 中的中文、空格与网络路径。
  static String? firstDroppedVideo(Iterable<Uri?> uris) {
    for (var uri in uris) {
      if (uri == null || uri.scheme != 'file') continue;
      try {
        var filePath = uri.toFilePath(windows: Platform.isWindows);
        if (path.isAbsolute(filePath) &&
            !path.isRootRelative(filePath) &&
            isVideo(filePath)) {
          return path.normalize(filePath);
        }
      } on ArgumentError {
        // Invalid file URIs must not prevent later files from being recognized.
      } on UnsupportedError {
        // File URIs with queries, fragments or invalid separators are ignored.
      }
    }
    return null;
  }

  /// 把下载任务里的相对路径解析到下载根目录，越界时抛
  /// [PlaybackUnavailable]。
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
}
