// Package imports:
import 'package:drift/drift.dart';

/// `AppPlaybackEpisodeRule`：条目作用域下的文件名匹配规则。
///
/// `offset` 以十进制文本存储，避免历史 schema 校验只认 INTEGER/TEXT。
@DataClassName('PlaybackEpisodeRuleRow')
class AppPlaybackEpisodeRule extends Table {
  @override
  String get tableName => 'AppPlaybackEpisodeRule';

  /// 规则 ID（主键）
  TextColumn get id => text()();

  /// 关联的 Bangumi 条目 ID
  IntColumn get subject => integer()();

  /// 捕获放送序号的正则
  TextColumn get pattern => text()();

  /// 序号偏移（十进制文本）
  TextColumn get offset => text()();

  /// 章节类型（BangumiEpType 取值 0–6）
  IntColumn get type => integer()();

  /// 用于校验捕获组的样例文件名
  TextColumn get exampleFile => text().named('exampleFile')();

  @override
  Set<Column> get primaryKey => {id};
}
