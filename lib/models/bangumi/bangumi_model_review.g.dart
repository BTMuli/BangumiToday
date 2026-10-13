// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bangumi_model_review.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BangumiSubjectReview _$BangumiSubjectReviewFromJson(
  Map<String, dynamic> json,
) => BangumiSubjectReview(
  id: (json['id'] as num).toInt(),
  user: BangumiCommentUser.fromJson(json['user'] as Map<String, dynamic>),
  entry: BangumiReviewSummary.fromJson(json['entry'] as Map<String, dynamic>),
);

Map<String, dynamic> _$BangumiSubjectReviewToJson(
  BangumiSubjectReview instance,
) => <String, dynamic>{
  'id': instance.id,
  'user': instance.user.toJson(),
  'entry': instance.entry.toJson(),
};

BangumiReviewSummary _$BangumiReviewSummaryFromJson(
  Map<String, dynamic> json,
) => BangumiReviewSummary(
  id: (json['id'] as num).toInt(),
  title: json['title'] as String,
  icon: json['icon'] as String,
  summary: json['summary'] as String,
  replies: (json['replies'] as num).toInt(),
  createdAt: (json['createdAt'] as num).toInt(),
);

Map<String, dynamic> _$BangumiReviewSummaryToJson(
  BangumiReviewSummary instance,
) => <String, dynamic>{
  'id': instance.id,
  'title': instance.title,
  'icon': instance.icon,
  'summary': instance.summary,
  'replies': instance.replies,
  'createdAt': instance.createdAt,
};

BangumiReviewDetail _$BangumiReviewDetailFromJson(Map<String, dynamic> json) =>
    BangumiReviewDetail(
      id: (json['id'] as num).toInt(),
      user: BangumiCommentUser.fromJson(json['user'] as Map<String, dynamic>),
      title: json['title'] as String,
      content: json['content'] as String,
      tags: (json['tags'] as List<dynamic>).map((e) => e as String).toList(),
      views: (json['views'] as num).toInt(),
      replies: (json['replies'] as num).toInt(),
      createdAt: (json['createdAt'] as num).toInt(),
      updatedAt: (json['updatedAt'] as num).toInt(),
    );

Map<String, dynamic> _$BangumiReviewDetailToJson(
  BangumiReviewDetail instance,
) => <String, dynamic>{
  'id': instance.id,
  'user': instance.user.toJson(),
  'title': instance.title,
  'content': instance.content,
  'tags': instance.tags,
  'views': instance.views,
  'replies': instance.replies,
  'createdAt': instance.createdAt,
  'updatedAt': instance.updatedAt,
};
