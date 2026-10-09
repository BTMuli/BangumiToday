// Package imports:
import 'package:json_annotation/json_annotation.dart';

// Project imports:
import 'bangumi_enum.dart';
import 'bangumi_model_user.dart';

part 'bangumi_model_comment.g.dart';

/// Next API 的条目吐槽，更新时间为 Unix 秒。
@JsonSerializable(explicitToJson: true)
class BangumiSubjectComment {
  const BangumiSubjectComment({
    required this.id,
    required this.user,
    required this.type,
    required this.rate,
    required this.comment,
    required this.updatedAt,
  });

  final int id;
  final BangumiCommentUser user;
  final BangumiCollectionType type;
  final int rate;
  final String comment;
  final int updatedAt;

  factory BangumiSubjectComment.fromJson(Map<String, dynamic> json) =>
      _$BangumiSubjectCommentFromJson(json);

  Map<String, dynamic> toJson() => _$BangumiSubjectCommentToJson(this);
}

/// Next API 的章节吐槽，[replies] 为同一吐槽下的回复。
/// 文档：https://github.com/bangumi/server-private/blob/master/openapi.json
@JsonSerializable(explicitToJson: true)
class BangumiEpisodeComment {
  const BangumiEpisodeComment({
    required this.id,
    required this.createdAt,
    required this.content,
    required this.user,
    required this.replies,
  });

  final int id;

  /// 发布时间，Unix 秒
  final int createdAt;
  final String content;
  final BangumiCommentUser user;
  final List<BangumiEpisodeCommentReply> replies;

  factory BangumiEpisodeComment.fromJson(Map<String, dynamic> json) =>
      _$BangumiEpisodeCommentFromJson(json);

  Map<String, dynamic> toJson() => _$BangumiEpisodeCommentToJson(this);
}

/// 章节吐槽下的回复，不支持再次嵌套。
@JsonSerializable(explicitToJson: true)
class BangumiEpisodeCommentReply {
  const BangumiEpisodeCommentReply({
    required this.id,
    required this.createdAt,
    required this.content,
    required this.user,
  });

  final int id;

  /// 发布时间，Unix 秒
  final int createdAt;
  final String content;
  final BangumiCommentUser user;

  factory BangumiEpisodeCommentReply.fromJson(Map<String, dynamic> json) =>
      _$BangumiEpisodeCommentReplyFromJson(json);

  Map<String, dynamic> toJson() => _$BangumiEpisodeCommentReplyToJson(this);
}

/// 吐槽接口返回的用户摘要，不包含 v0 用户模型的 user_group 字段。
@JsonSerializable(explicitToJson: true)
class BangumiCommentUser {
  const BangumiCommentUser({
    required this.id,
    required this.username,
    required this.nickname,
    required this.avatar,
  });

  final int id;
  final String username;
  final String nickname;
  final BangumiAvatar avatar;

  factory BangumiCommentUser.fromJson(Map<String, dynamic> json) =>
      _$BangumiCommentUserFromJson(json);

  Map<String, dynamic> toJson() => _$BangumiCommentUserToJson(this);
}
