// Package imports:
import 'package:json_annotation/json_annotation.dart';

// Project imports:
import 'bangumi_enum.dart';

part 'bangumi_model_user.g.dart';

/// User
@JsonSerializable(explicitToJson: true)
class BangumiUser {
  /// id
  @JsonKey(name: 'id')
  int id;

  /// username
  @JsonKey(name: 'username')
  String username;

  /// nickname
  @JsonKey(name: 'nickname')
  String nickname;

  /// user_group
  @JsonKey(name: 'user_group')
  BangumiLegacyUserGroupType userGroup;

  /// avatar
  @JsonKey(name: 'avatar')
  BangumiAvatar avatar;

  /// sign
  @JsonKey(name: 'sign')
  String sign;

  /// constructor
  BangumiUser({
    required this.id,
    required this.username,
    required this.nickname,
    required this.userGroup,
    required this.avatar,
    required this.sign,
  });

  /// from json
  factory BangumiUser.fromJson(Map<String, dynamic> json) =>
      _$BangumiUserFromJson(json);

  /// to json
  Map<String, dynamic> toJson() => _$BangumiUserToJson(this);
}

/// 通用模型-图片-用于用户
@JsonSerializable()
class BangumiAvatar {
  /// large
  @JsonKey(name: 'large')
  String large;

  /// medium
  @JsonKey(name: 'medium')
  String medium;

  /// small
  @JsonKey(name: 'small')
  String small;

  /// constructor
  BangumiAvatar({
    required this.large,
    required this.medium,
    required this.small,
  });

  /// from json
  factory BangumiAvatar.fromJson(Map<String, dynamic> json) =>
      _$BangumiAvatarFromJson(json);

  /// to json
  Map<String, dynamic> toJson() => _$BangumiAvatarToJson(this);
}
