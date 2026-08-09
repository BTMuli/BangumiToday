// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bangumi_model_user.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BangumiUser _$BangumiUserFromJson(Map<String, dynamic> json) => BangumiUser(
  id: (json['id'] as num).toInt(),
  username: json['username'] as String,
  nickname: json['nickname'] as String,
  userGroup: $enumDecode(
    _$BangumiLegacyUserGroupTypeEnumMap,
    json['user_group'],
  ),
  avatar: BangumiAvatar.fromJson(json['avatar'] as Map<String, dynamic>),
  sign: json['sign'] as String,
);

Map<String, dynamic> _$BangumiUserToJson(BangumiUser instance) =>
    <String, dynamic>{
      'id': instance.id,
      'username': instance.username,
      'nickname': instance.nickname,
      'user_group': _$BangumiLegacyUserGroupTypeEnumMap[instance.userGroup]!,
      'avatar': instance.avatar.toJson(),
      'sign': instance.sign,
    };

BangumiAvatar _$BangumiAvatarFromJson(Map<String, dynamic> json) =>
    BangumiAvatar(
      large: json['large'] as String,
      medium: json['medium'] as String,
      small: json['small'] as String,
    );

Map<String, dynamic> _$BangumiAvatarToJson(BangumiAvatar instance) =>
    <String, dynamic>{
      'large': instance.large,
      'medium': instance.medium,
      'small': instance.small,
    };

const _$BangumiLegacyUserGroupTypeEnumMap = {
  BangumiLegacyUserGroupType.admin: 1,
  BangumiLegacyUserGroupType.bangumiAdmin: 2,
  BangumiLegacyUserGroupType.windowAdmin: 3,
  BangumiLegacyUserGroupType.mutedUser: 4,
  BangumiLegacyUserGroupType.bannedUser: 5,
  BangumiLegacyUserGroupType.personAdmin: 8,
  BangumiLegacyUserGroupType.wikiAdmin: 9,
  BangumiLegacyUserGroupType.user: 10,
  BangumiLegacyUserGroupType.wikiUser: 11,
};
