// Package imports:
import 'package:drift/drift.dart';

/// `BangumiDataItem` 表：BangumiData 的条目离线库（本机约 8800 行）。
///
/// `titleTranslate` 与 `sites` 是 JSON 文本；同名条目由 itemKey 区分。
@DataClassName('DataItemRow')
@TableIndex(name: 'BangumiDataItem_title', columns: {#title})
@TableIndex(name: 'BangumiDataItem_itemKey', columns: {#itemKey}, unique: true)
class BangumiDataItem extends Table {
  @override
  String get tableName => 'BangumiDataItem';

  /// 自增主键
  IntColumn get id => integer().autoIncrement()();

  TextColumn get itemKey =>
      text().named('itemKey').withDefault(const Constant(''))();

  /// 作品标题
  TextColumn get title => text()();

  /// 标题翻译（JSON 文本）
  TextColumn get titleTranslate => text().named('titleTranslate').nullable()();

  /// 条目类型
  TextColumn get type => text().nullable()();

  /// 语言
  TextColumn get lang => text().nullable()();

  /// 官网
  TextColumn get officialSite => text().named('officialSite').nullable()();

  /// 开始日期
  TextColumn get begin => text().nullable()();

  /// 放送信息
  TextColumn get broadcast => text().nullable()();

  /// 结束日期
  TextColumn get end => text().nullable()();

  /// 备注
  TextColumn get comment => text().nullable()();

  /// 站点链接（JSON 文本）
  TextColumn get sites => text().nullable()();
}
