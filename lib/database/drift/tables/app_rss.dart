// Package imports:
import 'package:drift/drift.dart';

/// `AppRss` 表：RSS 抓取结果缓存。
///
/// 列名与 `lib/database/app/app_rss.dart` 的建表语句逐字对应。`data` 是
/// `xml.toXmlString` 后的 feed，`pendingItems` 是 JSON 数组文本，两者都保持
/// TEXT。
///
/// `pendingItems` / `cacheVersion` / `lastFailed` 是后续 `ALTER TABLE` 补的列，
/// 语句里虽然写了 `NOT NULL DEFAULT`，但补齐前的行不会因此变成非空之外的形态；
/// 这里按 DDL 声明非空，因为本机实测这些列没有 NULL。
@DataClassName('RssRow')
class AppRss extends Table {
  @override
  String get tableName => 'AppRss';

  /// RSS URL（主键）
  TextColumn get rss => text()();

  /// RSS 数据
  TextColumn get data => text().nullable()();

  /// mikan bangumi id
  TextColumn get mkBgmId => text().named('mkBgmId').nullable()();

  /// mikan group id
  TextColumn get mkGroupId => text().named('mkGroupId').nullable()();

  /// ttl
  IntColumn get ttl => integer()();

  /// 最近更新时间（epoch 毫秒）
  IntColumn get updated => integer()();

  /// RSS 更新后尚未由用户处理的条目标识（JSON 文本）
  TextColumn get pendingItems =>
      text().named('pendingItems').withDefault(const Constant('[]'))();

  /// 缓存版本
  IntColumn get cacheVersion =>
      integer().named('cacheVersion').withDefault(const Constant(1))();

  /// 最近一次刷新失败时间（epoch 毫秒），0 表示无失败
  IntColumn get lastFailed =>
      integer().named('lastFailed').withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {rss};
}
