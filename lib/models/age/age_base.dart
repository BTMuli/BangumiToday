// Package imports:
import 'package:json_annotation/json_annotation.dart';

part 'age_base.g.dart';

/// 通用的番剧数据
@JsonSerializable()
class BaseBangumi {
  /// anime id
  @JsonKey(name: 'AID')
  int aid;

  /// anime href
  @JsonKey(name: 'Href')
  String href;

  /// anime update title
  @JsonKey(name: 'NewTitle')
  String newTitle;

  /// anime update pic
  @JsonKey(name: 'PicSmall')
  String picSmall;

  /// anime title
  @JsonKey(name: 'Title')
  String title;

  /// constructor
  BaseBangumi({
    required this.aid,
    required this.href,
    required this.newTitle,
    required this.picSmall,
    required this.title,
  });

  /// from json
  factory BaseBangumi.fromJson(Map<String, dynamic> json) =>
      _$BaseBangumiFromJson(json);

  /// to json
  Map<String, dynamic> toJson() => _$BaseBangumiToJson(this);
}
