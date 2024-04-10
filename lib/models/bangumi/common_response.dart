import 'package:json_annotation/json_annotation.dart';

part 'common_response.g.dart';

/// 通用响应-未成功
@JsonSerializable()
class BangumiErrResponse {
  /// title
  @JsonKey(name: 'title')
  String title;

  /// description
  @JsonKey(name: 'description')
  String description;

  /// details
  @JsonKey(name: 'details')
  String details;

  /// constructor
  BangumiErrResponse({
    required this.title,
    required this.description,
    required this.details,
  });

  /// from json
  factory BangumiErrResponse.fromJson(Map<String, dynamic> json) =>
      _$BangumiErrResponseFromJson(json);

  /// to json
  Map<String, dynamic> toJson() => _$BangumiErrResponseToJson(this);
}
