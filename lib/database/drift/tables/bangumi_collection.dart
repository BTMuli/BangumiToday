// Package imports:
import 'package:drift/drift.dart';

/// `BangumiCollection` 表：登录用户的收藏缓存。
///
/// 列名、类型必须与 `lib/database/bangumi/bangumi_collection.dart` 的建表
/// 语句一致。`tags` 与 `subject` 是 JSON 文本，`updatedAt` 保持 TEXT
/// （与其他表的毫秒整数不同），`private` 是 0/1。
@DataClassName('CollectionRow')
class BangumiCollection extends Table {
  @override
  String get tableName => 'BangumiCollection';

  /// bangumi subject id（主键）
  IntColumn get subjectId => integer().named('subjectId')();

  /// 条目类型
  IntColumn get subjectType => integer().named('subjectType')();

  /// 评分
  IntColumn get rate => integer()();

  /// 收藏类型
  IntColumn get collectionType => integer().named('collectionType')();

  /// 短评
  TextColumn get comment => text().nullable()();

  /// 标签（JSON 文本）
  TextColumn get tags => text()();

  /// 已看话数
  IntColumn get epStat => integer().named('epStat')();

  /// 已看卷数
  IntColumn get volStat => integer().named('volStat')();

  /// 收藏更新时间（TEXT）
  TextColumn get updatedAt => text().named('updatedAt')();

  /// 是否私密收藏（0/1）
  IntColumn get private => integer().named('private')();

  /// 条目数据（JSON 文本）
  TextColumn get subject => text().nullable()();

  @override
  Set<Column> get primaryKey => {subjectId};
}
