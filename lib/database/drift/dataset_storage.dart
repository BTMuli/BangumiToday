// Package imports:
import 'package:drift/drift.dart';

// Project imports:
import 'bt_database.dart';

/// Offline BangumiData cache. Titles are lookup values, never identities.
class DatasetStorage {
  const DatasetStorage(this.db);
  final BtDatabase db;

  Future<List<DataItemRow>> readItems(String title) =>
      (db.select(db.bangumiDataItem)
            ..where((t) => t.title.equals(title))
            ..orderBy([(t) => OrderingTerm.asc(t.id)]))
          .get();

  Future<DataItemRow?> readItem(String title) =>
      (db.select(db.bangumiDataItem)
            ..where((t) => t.title.equals(title))
            ..orderBy([(t) => OrderingTerm.asc(t.id)])
            ..limit(1))
          .getSingleOrNull();

  /// 按 Bangumi 站点 ID 取首个非空简体译名，避免原名差异或同名作品误匹配。
  Future<String?> readSubjectNameCn(int subjectId) async {
    var row = await db
        .customSelect(
          '''
      SELECT title.value AS name_cn
      FROM BangumiDataItem AS item,
           json_each(item.titleTranslate, '\$."zh-Hans"') AS title
      WHERE title.type = 'text' AND title.value != ''
        AND EXISTS (
          SELECT 1 FROM json_each(item.sites) AS site
          WHERE json_extract(site.value, '\$.site') = 'bangumi'
            AND json_extract(site.value, '\$.id') = ?
        )
      ORDER BY item.id, title.key
      LIMIT 1
      ''',
          variables: [Variable(subjectId.toString())],
          readsFrom: {db.bangumiDataItem},
        )
        .getSingleOrNull();
    return row?.read<String>('name_cn');
  }

  /// 读取与放送窗口 [start, end) 相交的条目，保留窗口内尚未首播的新番。
  /// `begin`/`end` 为定长 ISO 8601 UTC 字符串；剧场版不进入日历。
  Future<List<DataItemRow>> readItemsInAirWindow({
    required DateTime start,
    required DateTime end,
  }) {
    var startUtc = start.toUtc().toIso8601String();
    var endUtc = end.toUtc().toIso8601String();
    return (db.select(db.bangumiDataItem)..where(
          (table) =>
              table.type.equals('movie').not() &
              table.begin.equals('').not() &
              table.begin.isSmallerThanValue(endUtc) &
              (table.end.isNull() |
                  table.end.equals('') |
                  table.end.isBiggerOrEqualValue(startUtc)),
        ))
        .get();
  }

  Future<void> saveSites(List<BangumiDataSiteCompanion> sites) =>
      db.transaction(() => _writeSites(sites));

  Future<void> _writeSites(List<BangumiDataSiteCompanion> sites) =>
      db.batch((batch) {
        for (var row in sites) {
          batch.insert(
            db.bangumiDataSite,
            row,
            onConflict: DoUpdate((_) => row, target: [db.bangumiDataSite.key]),
          );
        }
      });

  /// Incremental writes retain other items. Each chunk commits atomically.
  Future<void> saveItems(
    List<BangumiDataItemCompanion> items, {
    int batchSize = 200,
    void Function(int completed, int total)? onProgress,
  }) async {
    _validateItems(items, batchSize);
    await _writeItems(items, batchSize, onProgress);
  }

  void _validateItems(List<BangumiDataItemCompanion> items, int batchSize) {
    if (batchSize <= 0) throw ArgumentError.value(batchSize, 'batchSize');
    for (var item in items) {
      if (!item.itemKey.present || item.itemKey.value.isEmpty) {
        throw ArgumentError('数据集条目缺少身份键');
      }
    }
  }

  Future<void> _writeItems(
    List<BangumiDataItemCompanion> items,
    int batchSize,
    void Function(int completed, int total)? onProgress,
  ) async {
    for (var start = 0; start < items.length; start += batchSize) {
      var end = start + batchSize;
      if (end > items.length) end = items.length;
      await db.transaction(
        () => db.batch((batch) {
          for (var row in items.getRange(start, end)) {
            batch.insert(
              db.bangumiDataItem,
              row,
              onConflict: DoUpdate(
                (_) => row,
                target: [db.bangumiDataItem.itemKey],
              ),
            );
          }
        }),
      );
      onProgress?.call(end, items.length);
    }
  }

  /// Replace a complete upstream snapshot. Chunking bounds statement batches,
  /// but all items, sites, removals and version metadata share one transaction.
  /// Progress reports staged rows; completion is successful only after return.
  Future<void> replaceAll({
    required List<BangumiDataSiteCompanion> sites,
    required List<BangumiDataItemCompanion> items,
    required String version,
    required String checkedAt,
    int batchSize = 200,
    void Function(int completed, int total)? onProgress,
  }) async {
    _validateItems(items, batchSize);
    var keys = items.map((i) => i.itemKey.value).toSet();
    var siteKeys = sites.map((s) => s.key.value).toSet();
    if (items.isEmpty ||
        keys.length != items.length ||
        siteKeys.length != sites.length ||
        version.isEmpty) {
      throw ArgumentError('数据集为空、身份重复或版本缺失，保留现有快照');
    }
    await db.transaction(() async {
      await _writeSites(sites);
      await _writeItems(items, batchSize, onProgress);
      var table = db.bangumiDataItem;
      var existing = await (db.selectOnly(
        table,
      )..addColumns([table.id, table.itemKey])).get();
      var staleIds = existing
          .where((r) => !keys.contains(r.read(table.itemKey)))
          .map((r) => r.read(table.id)!)
          .toList();
      for (var start = 0; start < staleIds.length; start += batchSize) {
        var ids = staleIds.skip(start).take(batchSize).toList();
        await (db.delete(table)..where((t) => t.id.isIn(ids))).go();
      }
      var oldSites = await db.select(db.bangumiDataSite).get();
      await db.batch((batch) {
        for (var site in oldSites.where((s) => !siteKeys.contains(s.key))) {
          batch.deleteWhere(db.bangumiDataSite, (t) => t.key.equals(site.key));
        }
        batch.insertAllOnConflictUpdate(db.appConfig, [
          AppConfigCompanion.insert(key: 'bangumiDataVersion', value: version),
          AppConfigCompanion.insert(
            key: 'bangumiDataCheckTime',
            value: checkedAt,
          ),
        ]);
      });
    });
  }
}
