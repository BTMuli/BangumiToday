import 'dart:convert';

// Package imports:
import 'package:json_annotation/json_annotation.dart';

/// AppRss 表的数据模型
/// 该表在 lib/database/app/app_rss.dart 中定义
part 'app_rss_model.g.dart';

/// AppRss 表的数据模型
@JsonSerializable(explicitToJson: true)
class AppRssModel {
  /// RSS URL
  final String rss;

  /// mkBgmId
  String? mkBgmId;

  /// mkGroupId
  String? mkGroupId;

  /// RSS 数据，为xml.toXmlString后的feed
  String data;

  /// ttl
  int ttl;

  /// updated
  late int updated;

  /// RSS 更新后尚未由用户处理的条目标识。
  String pendingItems;

  /// 构造函数
  AppRssModel({
    required this.rss,
    required this.data,
    required this.ttl,
    this.updated = 0,
    this.mkBgmId,
    this.mkGroupId,
    this.pendingItems = '[]',
  });

  Set<String> get pendingItemKeys {
    try {
      var value = jsonDecode(pendingItems);
      if (value is! List) return {};
      return value.whereType<String>().toSet();
    } catch (_) {
      return {};
    }
  }

  void setPendingItemKeys(Iterable<String> keys) {
    pendingItems = jsonEncode(keys.toSet().toList());
  }

  /// JSON 序列化
  factory AppRssModel.fromJson(Map<String, dynamic> json) =>
      _$AppRssModelFromJson(json);

  /// JSON 反序列化
  Map<String, dynamic> toJson() => _$AppRssModelToJson(this);
}
