// Package imports:
import 'package:json_annotation/json_annotation.dart';

part 'mikan_model.g.dart';

/// 蜜柑计划搜索结果
@JsonSerializable()
class MikanSearchItemModel {
  /// 标题
  final String title;

  /// 链接
  final String link;

  /// 封面
  final String cover;

  /// ID
  final String id;

  /// rss
  final String rss;

  /// 构造函数
  MikanSearchItemModel({
    required this.title,
    required this.link,
    required this.cover,
    required this.id,
    required this.rss,
  });

  /// 反序列化
  factory MikanSearchItemModel.fromJson(Map<String, dynamic> json) =>
      _$MikanSearchItemModelFromJson(json);

  /// 序列化
  Map<String, dynamic> toJson() => _$MikanSearchItemModelToJson(this);
}
