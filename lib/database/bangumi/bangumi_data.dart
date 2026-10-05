// Package imports:
import 'package:drift/drift.dart';

// Project imports:
import '../../core/utils/bangumi_utils.dart';
import '../../models/bangumi/bangumi_data_model.dart';
import '../../tools/log_tool.dart';
import '../app/app_config.dart';
import '../bt_sqlite.dart';
import '../drift/bt_database.dart';
import '../drift/catalog_projection.dart';
import '../drift/dataset_storage.dart';

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
    var row = await DatasetStorage(_db).readItem(title);
    if (row == null) return null;
    return _itemFromRow(row);
  }

  /// 同名条目完整列表；readItem 保留返回最早本地 ID 的兼容语义。
  Future<List<BangumiDataItem>> readItems(String title) async =>
      (await DatasetStorage(_db).readItems(title)).map(_itemFromRow).toList();

  /// 读取首页七个日本放送日内的候选条目，包括本周尚未首播的新番。
  ///
  /// 窗口从 [at] 所在放送日的 0 点开始；分组时再核对每一天的首末播日期。
  Future<List<BangumiDataItem>> readItemsForCalendar({DateTime? at}) async {
    var start = bangumiCalendarStart(at: at);
    var rows = await DatasetStorage(_db).readItemsInAirWindow(
      start: start,
      end: start.add(const Duration(days: 7)),
    );
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
  /// 直接按唯一 key UPSERT，保留已有行 ID。
  Future<void> writeSite(BangumiDataSiteFull site) async {
    await DatasetStorage(_db).saveSites([_siteCompanion(site)]);
    BTLogTool.info('Write site data: ${site.key} - ${site.title}');
  }

  /// 写入更新站点元数据列表
  Future<void> writeSiteList(Map<String, BangumiDataSite> siteMap) async {
    await DatasetStorage(_db).saveSites([
      for (var entry in siteMap.entries)
        _siteCompanion(BangumiDataSiteFull.fromSite(entry.key, entry.value)),
    ]);
  }

  /// 写入/更新条目
  Future<void> writeItem(BangumiDataItem item) async {
    await writeItemBatch([item]);
    BTLogTool.info('Write item data: ${item.title}');
  }

  /// 写入更新条目列表
  Future<void> writeItemList(List<BangumiDataItem> itemList) async {
    await writeItemBatch(itemList);
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
    await DatasetStorage(_db).saveItems(
      items.map(_itemCompanion).toList(),
      batchSize: batchSize,
      onProgress: onProgress,
    );
  }

  /// 完整数据集、站点及版本原子更新，失败时保留上一份完整快照。
  Future<void> replaceDataset(
    BangumiDataJson data, {
    required String version,
    required String checkedAt,
    void Function(int completed, int total)? onProgress,
  }) => DatasetStorage(_db).replaceAll(
    sites: [
      for (var entry in data.siteMeta.entries)
        _siteCompanion(BangumiDataSiteFull.fromSite(entry.key, entry.value)),
    ],
    items: data.items.map(_itemCompanion).toList(),
    version: version,
    checkedAt: checkedAt,
    onProgress: onProgress,
  );

  Future<DataSiteRow?> _firstSiteByTitle(String title) {
    var query = _db.select(_db.bangumiDataSite)
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
      itemKey: Value(dataItemKey(values)!),
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
