// Package imports:
import 'package:drift/drift.dart';

/// `AppPlaybackEpisodeLink`：本地文件与章节的持久关联或显式排除。
///
/// 编码与 `PlaybackEpisodeLink` 一致：`pathKey` 为规范化绝对路径，
/// `episode` 为 null 表示该文件不属于该条目的任一章节。
@DataClassName('PlaybackEpisodeLinkRow')
class AppPlaybackEpisodeLink extends Table {
  @override
  String get tableName => 'AppPlaybackEpisodeLink';

  /// 规范化路径（主键），与 `PlaybackItem.pathKey` 相同。
  TextColumn get pathKey => text().named('pathKey')();

  /// 原始文件路径
  TextColumn get filePath => text().named('filePath')();

  /// 关联的 Bangumi 条目 ID
  IntColumn get subject => integer()();

  /// 章节 sort/ep；null 表示排除匹配
  IntColumn get episode => integer().nullable()();

  @override
  Set<Column> get primaryKey => {pathKey};
}
