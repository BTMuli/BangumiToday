// Package imports:
import 'package:drift/drift.dart';

// Project imports:
import '../../../models/database/app_bmf_model.dart';

/// `AppBmf` 表：Bangumi 条目与 Mikan RSS / 下载目录的订阅映射。
///
/// 列名必须与 `lib/database/app/app_bmf.dart` 的建表语句逐字对应，Drift 才能
/// 接管既有 SQLite 文件。Drift 默认把 getter 名转成 snake_case，本项目的列名
/// 是 camelCase，所以每个多词列都显式 `.named()`。
///
/// 可空性与 DDL 不同：`mkBgmId` / `mkGroupId` / `airDate` 在 DDL 里是
/// `TEXT DEFAULT ''`，但默认值不加 `NOT NULL`，旧版本插入的行实际会是 NULL
/// （本机实测 55 行里有 29 / 32 行为 NULL）。这里按**真实数据**声明可空，
/// 否则 Drift 读取时会因非空断言直接抛错。缺省值仍然保留，让新插入的行继续
/// 得到 `''`。`autoUpdate` 保持 INTEGER（0/1），让
/// [AppBmfModel.fromJson] 能直接消费行数据。
@DataClassName('BmfRow')
class AppBmf extends Table {
  @override
  String get tableName => 'AppBmf';

  /// 自增主键
  IntColumn get id => integer().autoIncrement()();

  /// bangumi subject id
  IntColumn get subject => integer().unique()();

  /// bangumi subject title
  TextColumn get title => text().nullable().withDefault(const Constant(''))();

  /// RSS URL
  TextColumn get rss => text().nullable()();

  /// 下载目录
  TextColumn get download => text().nullable()();

  /// mikan bangumi id
  TextColumn get mkBgmId =>
      text().named('mkBgmId').nullable().withDefault(const Constant(''))();

  /// mikan group id
  TextColumn get mkGroupId =>
      text().named('mkGroupId').nullable().withDefault(const Constant(''))();

  /// 放送日期
  TextColumn get airDate =>
      text().named('airDate').nullable().withDefault(const Constant(''))();

  /// 是否自动更新 RSS（0/1）
  IntColumn get autoUpdate =>
      integer().named('autoUpdate').withDefault(const Constant(1))();
}
