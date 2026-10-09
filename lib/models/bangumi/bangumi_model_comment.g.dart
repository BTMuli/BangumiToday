// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bangumi_model_comment.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BangumiSubjectComment _$BangumiSubjectCommentFromJson(
  Map<String, dynamic> json,
) => BangumiSubjectComment(
  id: (json['id'] as num).toInt(),
  user: BangumiCommentUser.fromJson(json['user'] as Map<String, dynamic>),
  type: $enumDecode(_$BangumiCollectionTypeEnumMap, json['type']),
  rate: (json['rate'] as num).toInt(),
  comment: json['comment'] as String,
  updatedAt: (json['updatedAt'] as num).toInt(),
);

Map<String, dynamic> _$BangumiSubjectCommentToJson(
  BangumiSubjectComment instance,
) => <String, dynamic>{
  'id': instance.id,
  'user': instance.user.toJson(),
  'type': _$BangumiCollectionTypeEnumMap[instance.type]!,
  'rate': instance.rate,
  'comment': instance.comment,
  'updatedAt': instance.updatedAt,
};

const _$BangumiCollectionTypeEnumMap = {
  BangumiCollectionType.unknown: 0,
  BangumiCollectionType.wish: 1,
  BangumiCollectionType.collect: 2,
  BangumiCollectionType.doing: 3,
  BangumiCollectionType.onHold: 4,
  BangumiCollectionType.dropped: 5,
};

BangumiEpisodeComment _$BangumiEpisodeCommentFromJson(
  Map<String, dynamic> json,
) => BangumiEpisodeComment(
  id: (json['id'] as num).toInt(),
  createdAt: (json['createdAt'] as num).toInt(),
  content: json['content'] as String,
  user: BangumiCommentUser.fromJson(json['user'] as Map<String, dynamic>),
  replies: (json['replies'] as List<dynamic>)
      .map(
        (e) => BangumiEpisodeCommentReply.fromJson(e as Map<String, dynamic>),
      )
      .toList(),
);

Map<String, dynamic> _$BangumiEpisodeCommentToJson(
  BangumiEpisodeComment instance,
) => <String, dynamic>{
  'id': instance.id,
  'createdAt': instance.createdAt,
  'content': instance.content,
  'user': instance.user.toJson(),
  'replies': instance.replies.map((e) => e.toJson()).toList(),
};

BangumiEpisodeCommentReply _$BangumiEpisodeCommentReplyFromJson(
  Map<String, dynamic> json,
) => BangumiEpisodeCommentReply(
  id: (json['id'] as num).toInt(),
  createdAt: (json['createdAt'] as num).toInt(),
  content: json['content'] as String,
  user: BangumiCommentUser.fromJson(json['user'] as Map<String, dynamic>),
);

Map<String, dynamic> _$BangumiEpisodeCommentReplyToJson(
  BangumiEpisodeCommentReply instance,
) => <String, dynamic>{
  'id': instance.id,
  'createdAt': instance.createdAt,
  'content': instance.content,
  'user': instance.user.toJson(),
};

BangumiCommentUser _$BangumiCommentUserFromJson(Map<String, dynamic> json) =>
    BangumiCommentUser(
      id: (json['id'] as num).toInt(),
      username: json['username'] as String,
      nickname: json['nickname'] as String,
      avatar: BangumiAvatar.fromJson(json['avatar'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$BangumiCommentUserToJson(BangumiCommentUser instance) =>
    <String, dynamic>{
      'id': instance.id,
      'username': instance.username,
      'nickname': instance.nickname,
      'avatar': instance.avatar.toJson(),
    };
