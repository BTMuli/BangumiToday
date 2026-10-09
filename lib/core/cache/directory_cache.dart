// Dart imports:
import 'dart:io';

// Package imports:
import 'package:path/path.dart' as path;

/// A snapshot prevents cleanup from deleting a file changed since the scan.
class CacheFile {
  const CacheFile(this.file, this.stat);

  final File file;
  final FileStat stat;

  Future<bool> deleteIfUnchanged(Directory root) async {
    try {
      if (!path.isWithin(root.path, file.path)) return false;
      var parent = file.parent;
      while (true) {
        if (await FileSystemEntity.type(parent.path, followLinks: false) !=
            FileSystemEntityType.directory) {
          return false;
        }
        if (path.equals(parent.path, root.path)) break;
        parent = parent.parent;
      }
      var type = await FileSystemEntity.type(file.path, followLinks: false);
      if (type == FileSystemEntityType.notFound) return true;
      if (type != FileSystemEntityType.file) return false;
      var current = await file.stat();
      if (current.size != stat.size || current.modified != stat.modified) {
        return false;
      }
      await file.delete();
      return true;
    } on FileSystemException {
      return false;
    }
  }
}

class DirectoryCache {
  const DirectoryCache(this.directory, {this.matches, this.recursive = false});

  final Directory directory;
  final bool Function(String name)? matches;
  final bool recursive;

  Future<List<CacheFile>> scan() async {
    var type = await FileSystemEntity.type(directory.path, followLinks: false);
    if (type == FileSystemEntityType.notFound) return [];
    if (type != FileSystemEntityType.directory) {
      throw FileSystemException('缓存路径不是普通目录', directory.path);
    }
    var files = <CacheFile>[];
    await for (var entity in directory.list(
      recursive: recursive,
      followLinks: false,
    )) {
      if (entity is! File ||
          !(matches?.call(path.basename(entity.path)) ?? true)) {
        continue;
      }
      var stat = await entity.stat();
      if (stat.type == FileSystemEntityType.file) {
        files.add(CacheFile(entity, stat));
      }
    }
    return files;
  }

  Future<int> getSize() async =>
      (await scan()).fold<int>(0, (sum, entry) => sum + entry.stat.size);

  /// Returns the number of files still in use or changed during cleanup.
  Future<int> clear() async {
    var failed = 0;
    for (var entry in await scan()) {
      if (!await entry.deleteIfUnchanged(directory)) failed++;
    }
    return failed;
  }
}

/// Engines hold a Windows no-delete-sharing lease while in use. Keep their
/// metadata whenever removal is refused, so other players can still reuse it.
class PlaybackEngineCache extends DirectoryCache {
  PlaybackEngineCache(super.directory) : super(matches: _matches);

  static final _engine = RegExp(r'^[a-f0-9]{64}\.engine$');
  static final _artifact = RegExp(
    r'^[a-f0-9]{64}\.engine'
    r'(?:\.(?:meta(?:\.part)?|used|part)|\.part-\d+-\d+\.log)?$',
  );

  static bool _matches(String name) => _artifact.hasMatch(name);

  @override
  Future<int> clear() async {
    var entries = await scan();
    // Build logs deny delete sharing while trtexec is running. Try them first
    // and preserve the entire engine group when a build is still active.
    int order(CacheFile entry) {
      var name = path.basename(entry.file.path);
      if (name.endsWith('.log')) return 0;
      return _engine.hasMatch(name) ? 1 : 2;
    }

    entries.sort((a, b) => order(a).compareTo(order(b)));
    var failed = 0;
    var building = <String>{};
    for (var entry in entries) {
      var name = path.basename(entry.file.path);
      var key = name.substring(0, 64);
      if (building.contains(key)) {
        failed++;
        continue;
      }
      if (name.endsWith('.meta') || name.endsWith('.used')) {
        var engine = entry.file.path.substring(0, entry.file.path.length - 5);
        if (await FileSystemEntity.type(engine, followLinks: false) !=
            FileSystemEntityType.notFound) {
          failed++;
          continue;
        }
      }
      if (!await entry.deleteIfUnchanged(directory)) {
        failed++;
        if (name.endsWith('.log')) building.add(key);
      }
    }
    return failed;
  }
}
