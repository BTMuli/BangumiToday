// Package imports:
import 'package:drift/drift.dart';

/// `AppPlayback` 表：本地视频的播放历史。
///
/// 编码约定与 `lib/models/playback/playback_item.dart` 一致：
/// `pathKey` 是小写规范化的绝对路径，`positionMs` / `durationMs` /
/// `updatedAt` 是整数毫秒，`completed` 是 0/1。
@DataClassName('PlaybackRow')
class AppPlayback extends Table {
  @override
  String get tableName => 'AppPlayback';

  /// 规范化路径（主键）
  TextColumn get pathKey => text().named('pathKey')();

  /// 原始文件路径
  TextColumn get filePath => text().named('filePath')();

  /// 显示标题
  TextColumn get title => text()();

  /// 关联的 Bangumi 条目 ID
  IntColumn get subject => integer().nullable()();

  /// 播放位置（毫秒）
  IntColumn get positionMs =>
      integer().named('positionMs').withDefault(const Constant(0))();

  /// 总时长（毫秒）
  IntColumn get durationMs =>
      integer().named('durationMs').withDefault(const Constant(0))();

  /// 是否已看完（0/1）
  IntColumn get completed => integer().withDefault(const Constant(0))();

  /// 最近更新时间（epoch 毫秒）
  IntColumn get updatedAt =>
      integer().named('updatedAt').withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {pathKey};
}
