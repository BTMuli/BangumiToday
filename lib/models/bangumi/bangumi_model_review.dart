// Package imports:
import 'package:json_annotation/json_annotation.dart';

// Project imports:
import 'bangumi_model_comment.dart';

part 'bangumi_model_review.g.dart';

/// 条目与评论日志的关联，关联 ID 与日志 ID 不同。
@JsonSerializable(explicitToJson: true)
class BangumiSubjectReview {
  const BangumiSubjectReview({
    required this.id,
    required this.user,
    required this.entry,
  });

  final int id;
  final BangumiCommentUser user;
  final BangumiReviewSummary entry;

  factory BangumiSubjectReview.fromJson(Map<String, dynamic> json) =>
      _$BangumiSubjectReviewFromJson(json);

  Map<String, dynamic> toJson() => _$BangumiSubjectReviewToJson(this);
}

/// Next API SlimBlogEntry 中用于条目评论列表的摘要。
@JsonSerializable(explicitToJson: true)
class BangumiReviewSummary {
  const BangumiReviewSummary({
    required this.id,
    required this.title,
    required this.icon,
    required this.summary,
    required this.replies,
    required this.createdAt,
  });

  final int id;
  final String title;
  final String icon;
  final String summary;
  final int replies;
  final int createdAt;

  factory BangumiReviewSummary.fromJson(Map<String, dynamic> json) =>
      _$BangumiReviewSummaryFromJson(json);

  Map<String, dynamic> toJson() => _$BangumiReviewSummaryToJson(this);
}

/// Next API BlogEntry 的评论正文，content 使用 BBCode，时间为 Unix 秒。
@JsonSerializable(explicitToJson: true)
class BangumiReviewDetail {
  const BangumiReviewDetail({
    required this.id,
    required this.user,
    required this.title,
    required this.content,
    required this.tags,
    required this.views,
    required this.replies,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final BangumiCommentUser user;
  final String title;
  final String content;
  final List<String> tags;
  final int views;
  final int replies;
  final int createdAt;
  final int updatedAt;

  factory BangumiReviewDetail.fromJson(Map<String, dynamic> json) =>
      _$BangumiReviewDetailFromJson(json);

  Map<String, dynamic> toJson() => _$BangumiReviewDetailToJson(this);
}
