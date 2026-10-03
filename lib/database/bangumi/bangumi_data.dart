// Package imports:
import 'package:drift/drift.dart';

// Project imports:
import '../../models/bangumi/bangumi_data_model.dart';
import '../../tools/log_tool.dart';
import '../app/app_config.dart';
import '../bt_sqlite.dart';
import '../drift/bt_database.dart';

/// 负责bangumi-data相关处理
/// 涉及 BangumiDataSite, BangumiDataItem, AppConfig三个表
/// AppConfig 里存储数据版本，数据库见 lib/database/app/app_config.dart
///
/// 建表与补列由 `BtDatabase` 拥有，这里只做表存取。
class BtsBangumiData {
  BtsBangumiData._();

  /// 实例
  static final BtsBangumiData _instance = BtsBangumiData._();

  /// 获取实例
  factory BtsBangumiData() => _instance;

  /// 数据库
  BtDatabase get _db => BTSqlite().db;

  /// 应用配置表
  final BtsAppConfig appConfig = BtsAppConfig();

  /// 读取全部站点元数据
  Future<List<BangumiDataSite>> readSiteAll() async {
    var rows = await _db.select(_db.bangumiDataSite).get();
    return rows.map(_siteFromRow).toList();
  }

  /// 读取全部条目
  Future<List<BangumiDataItem>> readItemAll() async {
    var rows = await _db.select(_db.bangumiDataItem).get();
    return rows.map(_itemFromRow).toList();
  }

  /// 读取特定站点元数据
  Future<BangumiDataSite?> readSite(String title) async {
    var row = await _firstSiteByTitle(title);
    if (row == null) return null;
    // `regions` 在库里是 JSON 文本，必须走 fromSqlJson 解析，不能直接喂
    // fromJson（后者期望的是 List）。
    return _siteFromRow(row);
  }

  /// 读取特定条目
  Future<BangumiDataItem?> readItem(String title) async {
    var row = await _firstItemByTitle(title);
    if (row == null) return null;
    return _itemFromRow(row);
  }

  /// 读取当前仍在放送的条目，供首页日历使用。
  ///
  /// `begin`/`end` 都是定长 ISO 8601 UTC 字符串，可直接按字符串比较：
  /// 已开播（`begin <= at`）且未结束（`end` 为空视为长期放送）。
  /// 剧场版没有固定放送时段，不进日历。
  Future<List<BangumiDataItem>> readItemsOnAir({DateTime? at}) async {
    var now = (at ?? DateTime.now()).toUtc().toIso8601String();
    var query = _db.select(_db.bangumiDataItem)
      ..where(
        (table) =>
            table.type.equals('movie').not() &
            table.begin.equals('').not() &
            table.begin.isSmallerOrEqualValue(now) &
            (table.end.isNull() |
                table.end.equals('') |
                table.end.isBiggerOrEqualValue(now)),
      );
    var rows = await query.get();
    return rows.map(_itemFromRow).toList();
  }

  /// 读取站点元数据映射，键为站点 key（如 `bangumi`）。
  Future<Map<String, BangumiDataSite>> readSiteMap() async {
    var rows = await _db.select(_db.bangumiDataSite).get();
    var map = <String, BangumiDataSite>{};
    for (var row in rows) {
      var site = _siteFromRow(row);
      map[site.key] = site;
    }
    return map;
  }

  /// 写入/更新站点元数据
  ///
  /// `key` 是唯一约束而不是主键（主键是自增 `id`），所以先按 key 查一次，
  /// 让既有行的 id 保持不变。
  Future<void> writeSite(BangumiDataSiteFull site) async {
    var existing = await _firstSite(site.key);
    if (existing == null) {
      await _db.into(_db.bangumiDataSite).insert(_siteCompanion(site));
      BTLogTool.info('Write site data: ${site.key} - ${site.title}');
      return;
    }
    var update = _db.update(_db.bangumiDataSite)
      ..where((table) => table.key.equals(site.key));
    await update.write(_siteCompanion(site));
    BTLogTool.info('Update site data: ${site.key} - ${site.title}');
  }

  /// 写入更新站点元数据列表
  Future<void> writeSiteList(Map<String, BangumiDataSite> siteMap) async {
    for (var entry in siteMap.entries) {
      var full = BangumiDataSiteFull.fromSite(entry.key, entry.value);
      await _instance.writeSite(full);
    }
  }

  /// 写入/更新条目
  Future<void> writeItem(BangumiDataItem item) async {
    var existing = await _firstItemByTitle(item.title);
    if (existing == null) {
      await _db.into(_db.bangumiDataItem).insert(_itemCompanion(item));
      BTLogTool.info('Write item data: ${item.title}');
      return;
    }
    await _updateItem(item);
    BTLogTool.info('Update item data: ${item.title}');
  }

  /// 写入更新条目列表
  Future<void> writeItemList(List<BangumiDataItem> itemList) async {
    for (var item in itemList) {
      await _instance.writeItem(item);
    }
  }

  /// 批量写入条目，按 [batchSize] 分批提交事务。
  ///
  /// 同一批内任一写入失败会回滚该批；已提交批次保持幂等，可断点重试。
  /// [onProgress] 在每批提交后回调（已完成数、总数），用于进度更新。
  Future<void> writeItemBatch(
    List<BangumiDataItem> items, {
    int batchSize = 200,
    void Function(int completed, int total)? onProgress,
  }) async {
    var total = items.length;
    if (total == 0) return;
    var completed = 0;
    for (var start = 0; start < total; start += batchSize) {
      var end = start + batchSize;
      if (end > total) end = total;
      var batch = items.sublist(start, end);
      await _db.transaction(() async {
        for (var item in batch) {
          if (await _firstItemByTitle(item.title) == null) {
            await _db.into(_db.bangumiDataItem).insert(_itemCompanion(item));
          } else {
            await _updateItem(item);
          }
        }
      });
      completed += batch.length;
      onProgress?.call(completed, total);
    }
  }

  Future<void> _updateItem(BangumiDataItem item) {
    var update = _db.update(_db.bangumiDataItem)
      ..where((table) => table.title.equals(item.title));
    return update.write(_itemCompanion(item));
  }

  Future<DataSiteRow?> _firstSite(String key) {
    var query = _db.select(_db.bangumiDataSite)
      ..where((table) => table.key.equals(key))
      ..limit(1);
    return query.getSingleOrNull();
  }

  Future<DataSiteRow?> _firstSiteByTitle(String title) {
    var query = _db.select(_db.bangumiDataSite)
      ..where((table) => table.title.equals(title))
      ..limit(1);
    return query.getSingleOrNull();
  }

  Future<DataItemRow?> _firstItemByTitle(String title) {
    var query = _db.select(_db.bangumiDataItem)
      ..where((table) => table.title.equals(title))
      ..limit(1);
    return query.getSingleOrNull();
  }

  BangumiDataSiteFull _siteFromRow(DataSiteRow row) {
    return BangumiDataSiteFull.fromSqlJson(row.toJson());
  }

  BangumiDataItem _itemFromRow(DataItemRow row) {
    return BangumiDataItem.fromSqlJson(row.toJson());
  }

  BangumiDataSiteCompanion _siteCompanion(BangumiDataSiteFull site) {
    var values = site.toSqlJson();
    return BangumiDataSiteCompanion(
      key: Value(values['key'] as String),
      title: Value(values['title'] as String),
      urlTemplate: Value(values['urlTemplate'] as String),
      type: Value(values['type'] as String),
      regions: Value(values['regions'] as String),
    );
  }

  BangumiDataItemCompanion _itemCompanion(BangumiDataItem item) {
    var values = item.toSqlJson();
    return BangumiDataItemCompanion(
      title: Value(values['title'] as String),
      titleTranslate: Value(values['titleTranslate'] as String),
      type: Value(values['type'] as String),
      lang: Value(values['lang'] as String),
      officialSite: Value(values['officialSite'] as String),
      begin: Value(values['begin'] as String),
      broadcast: Value(values['broadcast'] as String?),
      end: Value(values['end'] as String),
      comment: Value(values['comment'] as String?),
      sites: Value(values['sites'] as String),
    );
  }
}
