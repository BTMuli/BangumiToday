// Package imports:
import 'package:drift/drift.dart';

/// BMF parent identity and local download configuration.
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

  /// 下载目录
  TextColumn get download => text().nullable()();

  /// 放送日期
  TextColumn get airDate =>
      text().named('airDate').nullable().withDefault(const Constant(''))();
}
