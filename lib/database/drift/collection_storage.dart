// Package imports:
import 'package:drift/drift.dart';

// Project imports:
import 'bt_database.dart';
import 'catalog_projection.dart';

/// Keeps subject IDs stable and commits the complete list atomically.
class CollectionStorage {
  const CollectionStorage(this.db);
  final BtDatabase db;

  /// A single-account cache keeps its owner across restarts. Only the first
  /// upgrade may adopt legacy rows for the already signed-in account.
  Future<void> setOwner(String? username, {bool adoptLegacy = false}) =>
      db.transaction(() async {
        const key = 'bangumiCollectionOwner';
        var owner = await (db.select(
          db.appConfig,
        )..where((row) => row.key.equals(key))).getSingleOrNull();
        var next = username ?? '';
        if (username == null ||
            (owner?.value != next && !(owner == null && adoptLegacy))) {
          await db.delete(db.bangumiCollection).go();
        }
        await db
            .into(db.appConfig)
            .insertOnConflictUpdate(
              AppConfigCompanion.insert(key: key, value: next),
            );
      });

  /// Recheck after asynchronous writes too: a logout during the transaction
  /// must roll back the old response rather than repopulate another account.
  Future<bool> writeScoped(
    Future<void> Function() write, {
    required bool Function() isCurrent,
  }) async {
    try {
      return await db.transaction(() async {
        if (!isCurrent()) return false;
        await write();
        if (!isCurrent()) throw const _CollectionScopeChanged();
        return true;
      });
    } on _CollectionScopeChanged {
      return false;
    }
  }

  Future<void> replaceAll(
    Iterable<BangumiCollectionCompanion> collections, {
    int? type,
  }) => db.transaction(() async {
    var rows = collections.toList(growable: false);
    var ids = rows.map((row) => row.subjectId.value).toSet();
    await saveAll(rows);
    var table = db.bangumiCollection;
    var query = db.selectOnly(table)..addColumns([table.subjectId]);
    if (type != null) query.where(table.collectionType.equals(type));
    var stale = (await query.get())
        .map((row) => row.read(table.subjectId)!)
        .where((id) => !ids.contains(id))
        .toList();
    for (var start = 0; start < stale.length; start += 400) {
      await (db.delete(
        table,
      )..where((row) => row.subjectId.isIn(stale.skip(start).take(400)))).go();
    }
  });

  /// Observe IDs and collection types without decoding subject JSON.
  Stream<Map<int, int>> watchTypes() {
    var table = db.bangumiCollection;
    var query = db.selectOnly(table)
      ..addColumns([table.subjectId, table.collectionType]);
    return query.watch().map(
      (rows) => {
        for (var row in rows)
          row.read(table.subjectId)!: row.read(table.collectionType)!,
      },
    );
  }

  Future<void> saveAll(Iterable<BangumiCollectionCompanion> collections) async {
    var rows = collections
        .map((row) {
          if (!row.subject.present) {
            throw ArgumentError('收藏写入必须提供 subject，以同步标题投影');
          }
          var (name, nameCn) = collectionTitles(row.subject.value);
          return row.copyWith(name: Value(name), nameCn: Value(nameCn));
        })
        .toList(growable: false);
    if (rows.isEmpty) return;
    await db.transaction(
      () => db.batch((batch) {
        batch.insertAllOnConflictUpdate(db.bangumiCollection, rows);
      }),
    );
  }

  /// Scan only the covering title index, then load JSON for matching IDs.
  /// LIKE remains a substring scan; the projection avoids scanning JSON blobs.
  Future<List<CollectionRow>> search(String keyword, {int? type}) {
    var escaped = keyword
        .replaceAll('!', '!!')
        .replaceAll('%', '!%')
        .replaceAll('_', '!_');
    var table = db.bangumiCollection;
    var ids = db.selectOnly(table)..addColumns([table.subjectId]);
    ids.where(
      table.name.like('%$escaped%', escapeChar: '!') |
          table.nameCn.like('%$escaped%', escapeChar: '!'),
    );
    if (type != null) ids.where(table.collectionType.equals(type));
    return (db.select(table)
          ..where((t) => t.subjectId.isInQuery(ids) & t.subject.isNotNull())
          ..orderBy([(t) => OrderingTerm.asc(t.subjectId)]))
        .get();
  }
}

class _CollectionScopeChanged implements Exception {
  const _CollectionScopeChanged();
}
