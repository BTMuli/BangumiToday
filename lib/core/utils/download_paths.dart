// Dart imports:
import 'dart:io';

// Package imports:
import 'package:path/path.dart' as path;

class DownloadPaths {
  const DownloadPaths._();

  /// Recognize local torrent files, preserving Unicode, spaces and UNC paths.
  static List<String> droppedTorrents(Iterable<Uri?> uris) {
    var files = <String>[];
    var seen = <String>{};
    for (var uri in uris) {
      if (uri == null || uri.scheme != 'file') continue;
      try {
        var filePath = path.normalize(
          uri.toFilePath(windows: Platform.isWindows),
        );
        if (!path.isAbsolute(filePath) ||
            path.isRootRelative(filePath) ||
            path.extension(filePath).toLowerCase() != '.torrent') {
          continue;
        }
        var key = Platform.isWindows ? filePath.toLowerCase() : filePath;
        if (seen.add(key)) files.add(filePath);
      } on ArgumentError {
        // A malformed URI must not prevent later torrents from being added.
      } on UnsupportedError {
        // Ignore file URIs containing queries, fragments or bad separators.
      }
    }
    return files;
  }
}
