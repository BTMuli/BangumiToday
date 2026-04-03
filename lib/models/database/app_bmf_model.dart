// Package imports:
import 'package:json_annotation/json_annotation.dart';

/// AppBmf 表的数据模型
/// 该表在 lib/database/app/app_bmf.dart 中定义
part 'app_bmf_model.g.dart';

/// AppBmf 表的数据模型
@JsonSerializable()
class AppBmfModel {
  static const _unset = Object();

  /// ID
  final int id;

  /// bangumi subject id
  final int subject;

  /// bangumi subject title
  late String? title;

  /// RSS URL
  late String? rss;

  /// mikan bangymi id
  late String? mkBgmId;

  /// mikan group id
  late String? mkGroupId;

  /// 下载目录
  late String? download;

  /// 构造函数
  AppBmfModel({
    this.id = -1,
    required this.subject,
    this.title,
    this.rss,
    this.download,
    this.mkBgmId,
    this.mkGroupId,
  });

  /// JSON 序列化
  factory AppBmfModel.fromJson(Map<String, dynamic> json) =>
      _$AppBmfModelFromJson(json);

  /// JSON 反序列化
  Map<String, dynamic> toJson() => _$AppBmfModelToJson(this);

  /// 复制（支持设置 null 值）
  AppBmfModel copyWith({
    Object? id = _unset,
    Object? subject = _unset,
    Object? title = _unset,
    Object? rss = _unset,
    Object? mkBgmId = _unset,
    Object? mkGroupId = _unset,
    Object? download = _unset,
  }) {
    return AppBmfModel(
      id: id == _unset ? this.id : id as int,
      subject: subject == _unset ? this.subject : subject as int,
      title: title == _unset ? this.title : title as String?,
      rss: rss == _unset ? this.rss : rss as String?,
      mkBgmId: mkBgmId == _unset ? this.mkBgmId : mkBgmId as String?,
      mkGroupId: mkGroupId == _unset ? this.mkGroupId : mkGroupId as String?,
      download: download == _unset ? this.download : download as String?,
    );
  }
}
