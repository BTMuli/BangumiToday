// Package imports:
import 'package:drift/drift.dart';

/// `BangumiCollection` 表：登录用户的收藏缓存。
///
/// `tags` 与 `subject` 是 JSON 文本；标题投影供包含搜索使用。
@DataClassName('CollectionRow')
@TableIndex(
  name: 'BangumiCollection_search',
  columns: {#collectionType, #name, #nameCn},
)
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

  TextColumn get name => text().withDefault(const Constant(''))();
  TextColumn get nameCn =>
      text().named('nameCn').withDefault(const Constant(''))();

  @override
  Set<Column> get primaryKey => {subjectId};
}
