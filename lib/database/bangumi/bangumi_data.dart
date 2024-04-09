import '../../models/bangumi/data_item.dart';
import '../../models/bangumi/data_meta.dart';
import '../../tools/log_tool.dart';
import '../app/app_config.dart';
import '../bt_sqlite.dart';

/// 负责bangumi-data相关处理
/// 涉及 BangumiDataSite, BangumiDataItem, AppConfig三个表
/// todo 目前没有记录数据源版本
class BtsBangumiData {
  BtsBangumiData._();

  /// 实例
  static final BtsBangumiData _instance = BtsBangumiData._();

  /// 获取实例
  factory BtsBangumiData() => _instance;

  /// 数据库
  final BTSqlite sqlite = BTSqlite();

  /// 应用配置表
  final BtsAppConfig appConfig = BtsAppConfig();

  /// 表名-站点元数据
  final String _tableNameSite = 'BangumiDataSite';

  /// 表名-条目
  final String _tableNameItem = 'BangumiDataItem';

  /// 初始化站点元数据表
  /// 数据类型参考：lib/models/bangumi/data_meta.dart
  Future<void> initSite() async {
    var check = await _instance.sqlite.isTableExist(_tableNameSite);
    if (!check) {
      await _instance.sqlite.db.execute('''
        CREATE TABLE $_tableNameSite (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          key TEXT NOT NULL,
          title TEXT NOT NULL,
          urlTemplate TEXT NOT NULL,
          type TEXT,
          regions TEXT,
          UNIQUE(key)
        );
      ''');
      BTLogTool.info('Create table $_tableNameSite');
    } else {
      BTLogTool.warn('Table $_tableNameSite already exists');
      await _instance.sqlite.db.execute('DROP TABLE $_tableNameSite');
      BTLogTool.warn('Table $_tableNameSite dropped');
      await _instance.initSite();
    }
  }

  /// 初始化条目表
  /// 数据类型参考：lib/models/bangumi/data_item.dart
  Future<void> initItem() async {
    var check = await _instance.sqlite.isTableExist(_tableNameItem);
    if (!check) {
      await _instance.sqlite.db.execute('''
        CREATE TABLE $_tableNameItem (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          title TEXT NOT NULL,
          titleTranslate TEXT,
          type TEXT,
          lang TEXT,
          officialSite TEXT,
          begin TEXT,
          broadcast TEXT,
          end TEXT,
          comment TEXT,
          sites TEXT
        );
      ''');
      BTLogTool.info('Create table $_tableNameItem');
    } else {
      BTLogTool.warn('Table $_tableNameItem already exists');
      await _instance.sqlite.db.execute('DROP TABLE $_tableNameItem');
      BTLogTool.warn('Table $_tableNameItem dropped');
      await _instance.initItem();
    }
  }

  /// 前置检查-站点
  Future<void> preCheckSite() async {
    var check = await _instance.sqlite.isTableExist(_tableNameSite);
    if (!check) {
      BTLogTool.warn('Table $_tableNameSite not exists');
      await _instance.initSite();
    }
  }

  /// 前置检查-列表项
  Future<void> preCheckItem() async {
    var check = await _instance.sqlite.isTableExist(_tableNameItem);
    if (!check) {
      BTLogTool.warn('Table $_tableNameItem not exists');
      await _instance.initItem();
    }
  }

  /// 前置检查-通用
  Future<void> preCheck() async {
    await _instance.preCheckSite();
    await _instance.preCheckItem();
  }

  /// 读取全部站点元数据
  Future<List<BangumiDataSite>> readSiteAll() async {
    await _instance.preCheckSite();
    var result = await _instance.sqlite.db.query(_tableNameSite);
    BTLogTool.info('Read site data all: ${result.length}');
    return result.map(BangumiDataSite.fromJson).toList();
  }

  /// 读取全部条目
  Future<List<BangumiDataItem>> readItemAll() async {
    await _instance.preCheckItem();
    var result = await _instance.sqlite.db.query(_tableNameItem);
    BTLogTool.info('Read item data all: ${result.length}');
    return result.map(BangumiDataItem.fromJson).toList();
  }

  /// 读取特定站点元数据
  Future<BangumiDataSite?> readSite(String title) async {
    await _instance.preCheckSite();
    var result = await _instance.sqlite.db.query(
      _tableNameSite,
      where: 'title = ?',
      whereArgs: [title],
    );
    if (result.isEmpty) return null;
    BTLogTool.info('Read site data: $title');
    return BangumiDataSite.fromJson(result.first);
  }

  /// 读取特定条目
  Future<BangumiDataItem?> readItem(String title) async {
    await _instance.preCheckItem();
    var result = await _instance.sqlite.db.query(
      _tableNameItem,
      where: 'title = ?',
      whereArgs: [title],
    );
    if (result.isEmpty) return null;
    BTLogTool.info('Read item data: $title');
    return BangumiDataItem.fromJson(result.first);
  }

  /// 写入/更新站点元数据
  Future<void> writeSite(BangumiDataSiteFull site, {bool check = true}) async {
    if (check) await _instance.preCheckSite();
    var result = await _instance.sqlite.db.query(
      _tableNameSite,
      where: 'key = ?',
      whereArgs: [site.key],
    );
    if (result.isEmpty) {
      await _instance.sqlite.db.insert(_tableNameSite, site.toSqlJson());
      BTLogTool.info('Write site data: ${site.key} - ${site.title}');
    } else {
      await _instance.sqlite.db.update(
        _tableNameSite,
        site.toSqlJson(),
        where: 'key = ?',
        whereArgs: [site.key],
      );
      BTLogTool.info('Update site data: ${site.key} - ${site.title}');
    }
  }

  /// 写入更新站点元数据列表
  Future<void> writeSiteList(Map<String, BangumiDataSite> siteMap) async {
    await _instance.preCheck();
    for (var entry in siteMap.entries) {
      var full = BangumiDataSiteFull.fromSite(entry.key, entry.value);
      await _instance.writeSite(full, check: false);
    }
  }

  /// 写入/更新条目
  Future<void> writeItem(BangumiDataItem item, {bool check = true}) async {
    if (check) await _instance.preCheckItem();
    var result = await _instance.sqlite.db.query(
      _tableNameItem,
      where: 'title = ?',
      whereArgs: [item.title],
    );
    if (result.isEmpty) {
      await _instance.sqlite.db.insert(_tableNameItem, item.toSqlJson());
      BTLogTool.info('Write item data: ${item.title}');
    } else {
      await _instance.sqlite.db.update(
        _tableNameItem,
        item.toSqlJson(),
        where: 'title = ?',
        whereArgs: [item.title],
      );
      BTLogTool.info('Update item data: ${item.title}');
    }
  }

  /// 写入更新条目列表
  Future<void> writeItemList(List<BangumiDataItem> itemList) async {
    await _instance.preCheck();
    for (var item in itemList) {
      await _instance.writeItem(item, check: false);
    }
  }
}
