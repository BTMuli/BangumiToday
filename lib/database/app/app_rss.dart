// Package imports:
import 'package:drift/drift.dart';

// Project imports:
import '../../models/database/app_rss_model.dart';
import '../bt_sqlite.dart';
import '../drift/bt_database.dart';

/// AppRss 表，用于检测RSS订阅更新
/// 目前采取的是存储 RSS URL-RSS资源链接-获取时间 的方式
/// 通过比对获取时间来判断是否需要更新
///
/// 建表与补列由 `BtDatabase` 拥有，这里只做表存取。
class BtsAppRss {
  BtsAppRss._();

  /// 实例
  static final BtsAppRss instance = BtsAppRss._();

  /// 获取实例
  factory BtsAppRss() => instance;

  /// 数据库
  BtDatabase get _db => BTSqlite().db;

  /// 读取所有 rss 链接
  Future<List<AppRssModel>> readAll() async {
    var rows = await _db.select(_db.appRss).get();
    return rows.map((row) => AppRssModel.fromJson(row.toJson())).toList();
  }

  /// 读取配置
  Future<AppRssModel?> read(String rss) async {
    var row = await _firstByRss(rss);
    if (row == null) return null;
    return AppRssModel.fromJson(row.toJson());
  }

  /// 写入/更新配置
  Future<void> write(AppRssModel model) async {
    model.updated = DateTime.now().millisecondsSinceEpoch;
    model.lastFailed = 0;
    if (model.mkBgmId != null && model.mkBgmId!.isNotEmpty) {
      await writeByMkId(model);
      return;
    }
    if (await _firstByRss(model.rss) == null) {
      await _db.into(_db.appRss).insert(_companion(model));
    } else {
      await _updateByRss(model.rss, _companion(model));
    }
  }

  /// 删除配置
  Future<void> delete(String rss) async {
    var delete = _db.delete(_db.appRss)
      ..where((table) => table.rss.equals(rss));
    await delete.go();
  }

  /// 删除 Mikan URL
  Future<void> deleteByMkId(String s) async {
    var delete = _db.delete(_db.appRss)
      ..where((table) => table.mkBgmId.equals(s));
    await delete.go();
  }

  /// 读取 Mikan URL
  Future<AppRssModel?> readByMkId(String s) async {
    var row = await _firstByMkId(s);
    if (row == null) return null;
    return AppRssModel.fromJson(row.toJson());
  }

  /// 写入/更新配置
  Future<void> writeByMkId(AppRssModel model) async {
    model.updated = DateTime.now().millisecondsSinceEpoch;
    model.lastFailed = 0;
    var rssRow = await _firstByRss(model.rss);
    var mkRow = await _firstByMkId(model.mkBgmId);
    // 检测是否有rss重复
    if (rssRow != null) {
      // 如果有重复的，检测是否是同一个mkId
      if (rssRow.mkBgmId != model.mkBgmId) {
        await delete(model.rss);
      } else {
        // 如果是同一个mkId，更新数据
        await _updateByRss(model.rss, _companion(model));
      }
      return;
    }
    if (mkRow == null) {
      await _db.into(_db.appRss).insert(_companion(model));
    } else {
      await _updateByMkId(model.mkBgmId, _companion(model));
    }
  }

  /// 只更新待处理条目标识，不改变 RSS 的抓取时间。
  Future<void> updatePendingItems(AppRssModel model) async {
    var values = AppRssCompanion(pendingItems: Value(model.pendingItems));
    if (model.mkBgmId != null && model.mkBgmId!.isNotEmpty) {
      await _updateByMkId(model.mkBgmId, values);
      return;
    }
    await _updateByRss(model.rss, values);
  }

  /// 记录一次刷新失败，不清除最近成功时间。
  Future<void> markRefreshFailure(AppRssModel model) async {
    var now = DateTime.now().millisecondsSinceEpoch;
    var values = AppRssCompanion(lastFailed: Value(now));
    if (model.mkBgmId != null && model.mkBgmId!.isNotEmpty) {
      await _updateByMkId(model.mkBgmId, values);
      return;
    }
    await _updateByRss(model.rss, values);
  }

  Future<RssRow?> _firstByRss(String rss) {
    var query = _db.select(_db.appRss)
      ..where((table) => table.rss.equals(rss))
      ..limit(1);
    return query.getSingleOrNull();
  }

  Future<RssRow?> _firstByMkId(String? mkBgmId) {
    var query = _db.select(_db.appRss)
      ..where((table) => table.mkBgmId.equalsNullable(mkBgmId))
      ..limit(1);
    return query.getSingleOrNull();
  }

  Future<void> _updateByRss(String rss, AppRssCompanion values) {
    var update = _db.update(_db.appRss)
      ..where((table) => table.rss.equals(rss));
    return update.write(values);
  }

  Future<void> _updateByMkId(String? mkBgmId, AppRssCompanion values) {
    var update = _db.update(_db.appRss)
      ..where((table) => table.mkBgmId.equalsNullable(mkBgmId));
    return update.write(values);
  }

  AppRssCompanion _companion(AppRssModel model) {
    return AppRssCompanion(
      rss: Value(model.rss),
      data: Value(model.data),
      mkBgmId: Value(model.mkBgmId),
      mkGroupId: Value(model.mkGroupId),
      ttl: Value(model.ttl),
      updated: Value(model.updated),
      pendingItems: Value(model.pendingItems),
      cacheVersion: Value(model.cacheVersion),
      lastFailed: Value(model.lastFailed),
    );
  }
}
