import 'package:json_annotation/json_annotation.dart';

/// AppRss 表的数据模型
/// 该表在 lib/database/app/app_rss.dart 中定义
part 'app_rss_model.g.dart';

/// AppRss 表的数据模型
@JsonSerializable(explicitToJson: true)
class AppRssModel {
  /// RSS URL
  final String rss;

  /// RSS 数据，为xml.toXmlString后的feed
  String data;

  /// ttl
  int ttl;

  /// updated
  late int updated;

  /// 构造函数
  AppRssModel({
    required this.rss,
    required this.data,
    required this.ttl,
    this.updated = 0,
  });

  /// JSON 序列化
  factory AppRssModel.fromJson(Map<String, dynamic> json) =>
      _$AppRssModelFromJson(json);

  /// JSON 反序列化
  Map<String, dynamic> toJson() => _$AppRssModelToJson(this);
}
