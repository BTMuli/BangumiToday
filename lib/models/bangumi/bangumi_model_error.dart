// Package imports:
import 'package:json_annotation/json_annotation.dart';

part 'bangumi_model_error.g.dart';

/// ErrorDetail
@JsonSerializable()
class BangumiErrorDetail {
  /// title
  @JsonKey(name: 'title')
  String title;

  /// description
  @JsonKey(name: 'description')
  String description;

  /// details
  /// 可能是 string，也可能是 {error:string, path:string}
  @JsonKey(name: 'details')
  dynamic details;

  /// request_id
  @JsonKey(name: 'request_id')
  String requestId;

  /// constructor
  BangumiErrorDetail({
    required this.title,
    required this.description,
    required this.details,
    required this.requestId,
  });

  /// from json
  factory BangumiErrorDetail.fromJson(Map<String, dynamic> json) =>
      _$BangumiErrorDetailFromJson(json);

  /// to json
  Map<String, dynamic> toJson() => _$BangumiErrorDetailToJson(this);
}

/// oauthError
@JsonSerializable()
class BangumiErrorOauth {
  /// error
  @JsonKey(name: 'error')
  String error;

  /// error_description
  @JsonKey(name: 'error_description')
  String errorDescription;

  /// constructor
  BangumiErrorOauth({required this.error, required this.errorDescription});

  /// from json
  factory BangumiErrorOauth.fromJson(Map<String, dynamic> json) =>
      _$BangumiErrorOauthFromJson(json);

  /// to json
  Map<String, dynamic> toJson() => _$BangumiErrorOauthToJson(this);
}
