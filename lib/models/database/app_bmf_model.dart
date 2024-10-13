// Package imports:
import 'package:json_annotation/json_annotation.dart';

/// AppBmf 表的数据模型
/// 该表在 lib/database/app/app_bmf.dart 中定义
part 'app_bmf_model.g.dart';

/// AppBmf 表的数据模型
@JsonSerializable()
class AppBmfModel {
  /// ID
  final int id;

  /// bangumi subject id
  final int subject;

  /// bangumi subject title
  final String? title;

  /// RSS URL
  late String? rss;

  /// 下载目录
  late String? download;

  /// 构造函数
  AppBmfModel({
    this.id = -1,
    required this.subject,
    this.title,
    this.rss,
    this.download,
  });

  /// JSON 序列化
  factory AppBmfModel.fromJson(Map<String, dynamic> json) =>
      _$AppBmfModelFromJson(json);

  /// JSON 反序列化
  Map<String, dynamic> toJson() => _$AppBmfModelToJson(this);
}
