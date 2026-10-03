// Package imports:
import 'package:drift/drift.dart';

// Project imports:
import '../../models/playback/playback_item.dart';
import '../bt_sqlite.dart';
import '../drift/bt_database.dart';

/// Independent of the obsolete feat-vod-play Hive adapter IDs.
///
/// 表结构由 `BtDatabase` 拥有，这里不再自己建表。
class BtsAppPlayback {
  BtsAppPlayback({BtDatabase? database}) : _database = database;

  final BtDatabase? _database;

  /// 数据库
  BtDatabase get db => _database ?? BTSqlite().db;

  Future<List<PlaybackItem>> readAll() async {
    var query = db.select(db.appPlayback)
      ..orderBy([(table) => OrderingTerm.desc(table.updatedAt)]);
    var rows = await query.get();
    return rows.map((row) => PlaybackItem.fromRow(row.toJson())).toList();
  }

  Future<PlaybackItem?> read(String filePath) async {
    var query = db.select(db.appPlayback)
      ..where((table) => table.pathKey.equals(PlaybackItem.pathKey(filePath)));
    var row = await query.getSingleOrNull();
    return row == null ? null : PlaybackItem.fromRow(row.toJson());
  }

  Future<void> write(PlaybackItem item) async {
    await db.into(db.appPlayback).insertOnConflictUpdate(_companion(item));
  }

  Future<void> delete(String filePath) async {
    var delete = db.delete(db.appPlayback)
      ..where((table) => table.pathKey.equals(PlaybackItem.pathKey(filePath)));
    await delete.go();
  }

  AppPlaybackCompanion _companion(PlaybackItem item) {
    return AppPlaybackCompanion(
      pathKey: Value(item.key),
      filePath: Value(item.filePath),
      title: Value(item.title),
      subject: Value(item.subject),
      positionMs: Value(item.positionMs),
      durationMs: Value(item.durationMs),
      completed: Value(item.completed ? 1 : 0),
      updatedAt: Value(item.updatedAt),
    );
  }
}
