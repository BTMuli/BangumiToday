// Dart imports:
import 'dart:io';

// Package imports:
import 'package:path/path.dart' as path;

/// Keep the OS lock for the entire lifetime of the database connection.
/// The persistent lock file is never deleted, avoiding inode replacement races.
class DatabaseProcessLock {
  DatabaseProcessLock._(this._file, this._key);

  final RandomAccessFile _file;
  final String _key;
  static final Set<String> _held = {};
  bool _released = false;

  static Future<DatabaseProcessLock> acquire(String databasePath) async {
    var directory = Directory(path.dirname(databasePath));
    await directory.create(recursive: true);
    var canonicalDirectory = await directory.resolveSymbolicLinks();
    var canonicalFile = File(databasePath);
    var canonicalPath = await canonicalFile.exists()
        ? await canonicalFile.resolveSymbolicLinks()
        : path.join(canonicalDirectory, path.basename(databasePath));
    var lockPath = '$canonicalPath.lock';
    var key = Platform.isWindows ? lockPath.toLowerCase() : lockPath;
    if (!_held.add(key)) {
      throw StateError('数据库已经在当前进程中打开');
    }
    RandomAccessFile? file;
    try {
      file = await File(lockPath).open(mode: FileMode.append);
      await file.lock(FileLock.exclusive, 0, 1);
      return DatabaseProcessLock._(file, key);
    } catch (_) {
      _held.remove(key);
      await file?.close();
      throw StateError('数据库正在由另一个客户端使用，请完全退出后重试');
    }
  }

  Future<void> release() async {
    if (_released) return;
    _released = true;
    try {
      await _file.unlock(0, 1);
    } finally {
      _held.remove(_key);
      await _file.close();
    }
  }
}
