// Package imports:
import 'package:drift/drift.dart';

/// `BangumiUser` 表：用户信息与授权。
///
/// 值统一存 TEXT。`accessToken` / `refreshToken` 现在优先存放在系统安全存储，
/// 这张表只在安全存储不可用时作为回落路径；schema 必须保留该表原样。
@DataClassName('UserRow')
class BangumiUser extends Table {
  @override
  String get tableName => 'BangumiUser';

  /// 键（主键）：user / expireTime / accessToken / refreshToken
  TextColumn get key => text()();

  /// 值
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}
