// Package imports:
import 'package:drift/drift.dart';

/// `AppConfig` 表：通用配置键值。
///
/// 值统一存 TEXT（新值是 JSON 文本或纯字符串），与
/// `lib/database/app/app_config.dart` 的建表语句一致。
@DataClassName('ConfigRow')
class AppConfig extends Table {
  @override
  String get tableName => 'AppConfig';

  /// 配置键（主键）
  TextColumn get key => text()();

  /// 配置值
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}
