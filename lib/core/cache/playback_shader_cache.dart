// Dart imports:
import 'dart:io';

// Package imports:
import 'package:path/path.dart' as path;

/// On-disk compiled mpv shaders, separate from image and application caches.
class PlaybackShaderCache {
  PlaybackShaderCache(
    this.directory, {
    this.capacityBytes = defaultCapacityBytes,
    this.maxAge = defaultMaxAge,
  }) : assert(capacityBytes >= 0),
       assert(!maxAge.isNegative);

  static const defaultCapacityBytes = 128 * 1024 * 1024;
  static const defaultMaxAge = Duration(days: 30);

  // mpv names compiled programs with their SHA-256 hash. Preserve unrelated
  // files, directories and links, including manually saved shader sources.
  static final _cacheName = RegExp(r'^[0-9a-fA-F]{64}$');

  final Directory directory;
  final int capacityBytes;
  final Duration maxAge;

  Future<void> ensureDirectory() async {
    await _checkDirectory();
    await directory.create(recursive: true);
  }

  Future<int> getSize() async {
    var files = await _scan();
    return files.fold<int>(0, (total, entry) => total + entry.stat.size);
  }

  Future<ShaderCacheCleanupResult> clear() async {
    return _remove(await _scan(), clearAll: true);
  }

  /// Expiry uses the last write time; mpv cache hits do not refresh it.
  Future<ShaderCacheCleanupResult> prune({DateTime? now}) async {
    return _remove(await _scan(), now: now ?? DateTime.now());
  }

  Future<FileSystemEntityType> _checkDirectory() async {
    var type = await FileSystemEntity.type(directory.path, followLinks: false);
    if (type != FileSystemEntityType.directory &&
        type != FileSystemEntityType.notFound) {
      throw FileSystemException('Shader 缓存路径不是普通目录', directory.path);
    }
    return type;
  }

  Future<List<_ShaderCacheFile>> _scan() async {
    if (await _checkDirectory() == FileSystemEntityType.notFound) return [];
    var files = <_ShaderCacheFile>[];
    await for (var entity in directory.list(followLinks: false)) {
      if (entity is! File || !_cacheName.hasMatch(path.basename(entity.path))) {
        continue;
      }
      var stat = await entity.stat();
      if (stat.type == FileSystemEntityType.file) {
        files.add(_ShaderCacheFile(entity, stat));
      }
    }
    return files;
  }

  Future<ShaderCacheCleanupResult> _remove(
    List<_ShaderCacheFile> files, {
    bool clearAll = false,
    DateTime? now,
  }) async {
    files.sort((a, b) {
      var order = a.stat.modified.compareTo(b.stat.modified);
      return order != 0 ? order : a.file.path.compareTo(b.file.path);
    });
    var remainingBytes = files.fold<int>(
      0,
      (total, entry) => total + entry.stat.size,
    );
    var cutoff = now?.subtract(maxAge);
    var deletedFiles = 0;
    var deletedBytes = 0;
    var failedFiles = 0;
    for (var entry in files) {
      var expired = cutoff != null && !entry.stat.modified.isAfter(cutoff);
      if (!clearAll && !expired && remainingBytes <= capacityBytes) continue;
      if (await _deleteUnchanged(entry)) {
        remainingBytes -= entry.stat.size;
        deletedBytes += entry.stat.size;
        deletedFiles++;
      } else {
        // Files being compiled or held open are retried at the next cleanup.
        failedFiles++;
      }
    }
    return ShaderCacheCleanupResult(deletedFiles, deletedBytes, failedFiles);
  }

  Future<bool> _deleteUnchanged(_ShaderCacheFile entry) async {
    try {
      var type = await FileSystemEntity.type(
        entry.file.path,
        followLinks: false,
      );
      if (type == FileSystemEntityType.notFound) return true;
      if (type != FileSystemEntityType.file) return false;
      var current = await entry.file.stat();
      if (current.type == FileSystemEntityType.notFound) return true;
      if (current.size != entry.stat.size ||
          current.modified != entry.stat.modified) {
        return false;
      }
      await entry.file.delete();
      return true;
    } on FileSystemException {
      return false;
    }
  }
}

class ShaderCacheCleanupResult {
  const ShaderCacheCleanupResult(
    this.deletedFiles,
    this.deletedBytes,
    this.failedFiles,
  );

  final int deletedFiles;
  final int deletedBytes;
  final int failedFiles;
}

class _ShaderCacheFile {
  const _ShaderCacheFile(this.file, this.stat);

  final File file;
  final FileStat stat;
}
