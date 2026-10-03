// Package imports:
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// Project imports:
import '../../models/playback/playback_item.dart';
import '../bt_sqlite.dart';

/// Independent of the obsolete feat-vod-play Hive adapter IDs.
class BtsAppPlayback {
  final Database db;
  Future<void>? _ready;

  BtsAppPlayback({Database? database}) : db = database ?? BTSqlite().db;

  Future<void> preCheck() => _ready ??= _createTable().catchError((
    Object error,
    StackTrace stackTrace,
  ) {
    _ready = null;
    Error.throwWithStackTrace(error, stackTrace);
  });

  Future<void> _createTable() async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS AppPlayback (
        pathKey TEXT PRIMARY KEY,
        filePath TEXT NOT NULL,
        title TEXT NOT NULL,
        subject INTEGER,
        positionMs INTEGER NOT NULL DEFAULT 0,
        durationMs INTEGER NOT NULL DEFAULT 0,
        completed INTEGER NOT NULL DEFAULT 0,
        updatedAt INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  Future<List<PlaybackItem>> readAll() async {
    await preCheck();
    var rows = await db.query('AppPlayback', orderBy: 'updatedAt DESC');
    return rows.map(PlaybackItem.fromRow).toList();
  }

  Future<PlaybackItem?> read(String filePath) async {
    await preCheck();
    var rows = await db.query(
      'AppPlayback',
      where: 'pathKey = ?',
      whereArgs: [PlaybackItem.pathKey(filePath)],
      limit: 1,
    );
    return rows.isEmpty ? null : PlaybackItem.fromRow(rows.first);
  }

  Future<void> write(PlaybackItem item) async {
    await preCheck();
    await db.insert(
      'AppPlayback',
      item.toRow(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> delete(String filePath) async {
    await preCheck();
    await db.delete(
      'AppPlayback',
      where: 'pathKey = ?',
      whereArgs: [PlaybackItem.pathKey(filePath)],
    );
  }
}
