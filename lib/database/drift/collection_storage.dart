// Project imports:
import 'bt_database.dart';

/// Keeps subject IDs stable and commits the complete list atomically.
class CollectionStorage {
  const CollectionStorage(this.db);
  final BtDatabase db;

  Future<void> saveAll(Iterable<BangumiCollectionCompanion> collections) async {
    var rows = collections.toList(growable: false);
    if (rows.isEmpty) return;
    await db.transaction(
      () => db.batch((batch) {
        batch.insertAllOnConflictUpdate(db.bangumiCollection, rows);
      }),
    );
  }
}
