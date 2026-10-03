// Package imports:
import 'package:drift/drift.dart';

/// `BangumiDataSite` 表：BangumiData 的站点元数据。
///
/// `key` 有 UNIQUE 约束（既是业务键也是 upsert 目标），`regions` 是 JSON
/// 文本。与 `lib/database/bangumi/bangumi_data.dart` 的建表语句一致。
@DataClassName('DataSiteRow')
class BangumiDataSite extends Table {
  @override
  String get tableName => 'BangumiDataSite';

  /// 自增主键
  IntColumn get id => integer().autoIncrement()();

  /// 站点键
  TextColumn get key => text().unique()();

  /// 站点标题
  TextColumn get title => text()();

  /// URL 模板
  TextColumn get urlTemplate => text().named('urlTemplate')();

  /// 站点类型
  TextColumn get type => text().nullable()();

  /// 地区列表（JSON 文本）
  TextColumn get regions => text().nullable()();
}
