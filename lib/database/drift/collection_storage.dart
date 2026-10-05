// Package imports:
import 'package:drift/drift.dart';

// Project imports:
import 'bt_database.dart';
import 'catalog_projection.dart';

/// Keeps subject IDs stable and commits the complete list atomically.
class CollectionStorage {
  const CollectionStorage(this.db);
  final BtDatabase db;

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
