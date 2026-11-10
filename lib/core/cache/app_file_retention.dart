// Dart imports:
import 'dart:io';

// Package imports:
import 'package:path/path.dart' as path;

// Project imports:
import 'directory_cache.dart';

/// Only application-owned backups and interrupted TensorRT installs are aged.
class AppFileRetention {
  const AppFileRetention();

  static const backupRetention = Duration(days: 30);
  static const downloadRetention = Duration(days: 14);
  static final _backup = RegExp(r'^BangumiToday\.pre-migration-\d+\.db$');
  static final _download = RegExp(r'^[0-9a-f]{64}\.7z\.part(?:\.etag)?$');
  static final _version = RegExp(r'^\d+(?:\.\d+)+$');
  static final _interrupted = RegExp(
    r'^sm\d+\.(?:staging-\d+-\d+(?:-interrupted-\d+)?|invalid-\d+-\d+)$',
  );

  Future<void> pruneBackups(Directory directory, {DateTime? now}) async {
    var cutoff = (now ?? DateTime.now()).subtract(backupRetention);
    for (var entry in await DirectoryCache(
      directory,
      matches: _backup.hasMatch,
    ).scan()) {
      if (!entry.stat.modified.isAfter(cutoff)) {
        await entry.deleteIfUnchanged(directory);
      }
    }
  }

  Future<void> pruneDownloads(Directory root, {DateTime? now}) async {
    var type = await FileSystemEntity.type(root.path, followLinks: false);
    if (type == FileSystemEntityType.notFound) return;
    if (type != FileSystemEntityType.directory) {
      throw FileSystemException('TensorRT 缓存路径不是普通目录', root.path);
    }
    var lock = File(path.join(root.path, 'install.lock'));
    var lockType = await FileSystemEntity.type(lock.path, followLinks: false);
    if (lockType != FileSystemEntityType.file &&
        lockType != FileSystemEntityType.notFound) {
      return;
    }
    var handle = await lock.open(mode: FileMode.append);
    var locked = false;
    try {
      try {
        // The installer uses the same non-blocking OS lock across windows.
        await handle.lock(FileLock.exclusive);
        locked = true;
      } on FileSystemException {
        return;
      }
      var cutoff = (now ?? DateTime.now()).subtract(downloadRetention);
      var downloads = Directory(path.join(root.path, 'downloads'));
      var groups = <String, List<CacheFile>>{};
      for (var entry in await DirectoryCache(
        downloads,
        matches: _download.hasMatch,
      ).scan()) {
        var key = entry.file.path.replaceFirst(RegExp(r'\.etag$'), '');
        groups.putIfAbsent(key, () => []).add(entry);
      }
      for (var group in groups.values) {
        // A current partial download also keeps its older ETag sidecar.
        if (group.any((entry) => entry.stat.modified.isAfter(cutoff))) {
          continue;
        }
        for (var entry in group) {
          await entry.deleteIfUnchanged(downloads);
        }
      }
      await for (var version in root.list(followLinks: false)) {
        if (version is! Directory ||
            !_version.hasMatch(path.basename(version.path))) {
          continue;
        }
        await for (var entry in version.list(followLinks: false)) {
          if (entry is Directory &&
              _interrupted.hasMatch(path.basename(entry.path))) {
            await _pruneInterrupted(entry, cutoff);
          }
        }
      }
    } finally {
      try {
        if (locked) await handle.unlock();
      } finally {
        await handle.close();
      }
    }
  }

  Future<void> _pruneInterrupted(Directory root, DateTime cutoff) async {
    var directories = <Directory>[root];
    var files = <CacheFile>[];
    if ((await root.stat()).modified.isAfter(cutoff)) return;
    await for (var entry in root.list(recursive: true, followLinks: false)) {
      if (entry is Link) return;
      var stat = await entry.stat();
      if (stat.modified.isAfter(cutoff)) return;
      if (entry is Directory) directories.add(entry);
      if (entry is File) files.add(CacheFile(entry, stat));
    }
    for (var file in files) {
      if (!await file.deleteIfUnchanged(root)) return;
    }
    directories.sort((a, b) => b.path.length.compareTo(a.path.length));
    for (var directory in directories) {
      try {
        if (await FileSystemEntity.type(directory.path, followLinks: false) ==
            FileSystemEntityType.directory) {
          await directory.delete();
        }
      } on FileSystemException {
        // A busy or changed directory is retried during the next maintenance.
      }
    }
  }
}
