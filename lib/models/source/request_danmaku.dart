// Package imports:
import 'package:json_annotation/json_annotation.dart';

// Project imports:
import '../app/response.dart';
import 'danmaku_enum.dart';

/// DandanPlay 相关接口返回
/// 这边只写了一部分，因为不是所有的接口都需要
part 'request_danmaku.g.dart';

/// DandanPlay 作品查找返回
@JsonSerializable()
class DanmakuSearchAnimeResponse {
  /// 作品列表
  @JsonKey(name: 'animes')
  final List<DanmakuSearchAnimeDetails>? list;

  /// 错误代码
  @JsonKey(name: 'errorCode')
  final int errorCode;

  /// 是否调用成功
  @JsonKey(name: 'success')
  final bool success;

  /// 错误信息
  @JsonKey(name: 'errorMessage')
  final String? errorMessage;

  /// constructor
  DanmakuSearchAnimeResponse({
    required this.list,
    required this.errorCode,
    required this.success,
    required this.errorMessage,
  });

  /// from json
  factory DanmakuSearchAnimeResponse.fromJson(Map<String, dynamic> json) =>
      _$DanmakuSearchAnimeResponseFromJson(json);

  /// to json
  Map<String, dynamic> toJson() => _$DanmakuSearchAnimeResponseToJson(this);

  /// to BTResponse
  BTResponse<DanmakuSearchAnimeResponse> toBTResponse() =>
      BTResponse<DanmakuSearchAnimeResponse>(
          code: errorCode, message: errorMessage ?? '', data: this);
}

/// DandanPlay 作品详情
@JsonSerializable()
class DanmakuSearchAnimeDetails {
  /// 作品 ID
  @JsonKey(name: 'animeId')
  final int animeId;

  /// 作品名称
  @JsonKey(name: 'animeTitle')
  final String? animeTitle;

  /// 作品类型
  @JsonKey(name: 'type')
  final DanmakuAnimeType type;

  /// 类型描述
  @JsonKey(name: 'typeDescription')
  final String? typeDescription;

  /// 图片地址
  @JsonKey(name: 'imageUrl')
  final String? imageUrl;

  /// 上映日期
  @JsonKey(name: 'startDate')
  final String startDate;

  /// 剧集总数
  @JsonKey(name: 'episodeCount')
  final int episodeCount;

  /// 综合评分
  @JsonKey(name: 'rating')
  final double rating;

  /// 是否关注
  @JsonKey(name: 'isFavorited')
  final bool isFavorited;

  /// constructor
  DanmakuSearchAnimeDetails({
    required this.animeId,
    required this.animeTitle,
    required this.type,
    required this.typeDescription,
    required this.imageUrl,
    required this.startDate,
    required this.episodeCount,
    required this.rating,
    required this.isFavorited,
  });

  /// from json
  factory DanmakuSearchAnimeDetails.fromJson(Map<String, dynamic> json) =>
      _$DanmakuSearchAnimeDetailsFromJson(json);

  /// to json
  Map<String, dynamic> toJson() => _$DanmakuSearchAnimeDetailsToJson(this);
}

/// DandanPlay 章节查找返回
@JsonSerializable()
class DanmakuSearchEpisodesResponse {
  /// 是否有更多
  @JsonKey(name: 'hasMore')
  final bool hasMore;

  /// 章节列表
  @JsonKey(name: 'animes')
  final List<DanmakuSearchEpisodesAnime>? animes;

  /// 错误代码
  @JsonKey(name: 'errorCode')
  final int errorCode;

  /// 是否调用成功
  @JsonKey(name: 'success')
  final bool success;

  /// 错误信息
  @JsonKey(name: 'errorMessage')
  final String? errorMessage;

  /// constructor
  DanmakuSearchEpisodesResponse({
    required this.hasMore,
    required this.animes,
    required this.errorCode,
    required this.success,
    required this.errorMessage,
  });

  /// from json
  factory DanmakuSearchEpisodesResponse.fromJson(Map<String, dynamic> json) =>
      _$DanmakuSearchEpisodesResponseFromJson(json);

  /// to json
  Map<String, dynamic> toJson() => _$DanmakuSearchEpisodesResponseToJson(this);

  /// to BTResponse
  BTResponse<DanmakuSearchEpisodesResponse> toBTResponse() =>
      BTResponse<DanmakuSearchEpisodesResponse>(
          code: errorCode, message: errorMessage ?? '', data: this);
}

/// DandanPlay 章节查找返回
@JsonSerializable()
class DanmakuSearchEpisodesAnime {
  /// 作品 ID
  @JsonKey(name: 'animeId')
  final int animeId;

  /// 作品名称
  @JsonKey(name: 'animeTitle')
  final String? animeTitle;

  /// 作品类型
  @JsonKey(name: 'type')
  final DanmakuAnimeType type;

  /// 类型描述
  @JsonKey(name: 'typeDescription')
  final String? typeDescription;

  /// 剧集列表
  @JsonKey(name: 'episodes')
  final List<DanmakuSearchEpisodeDetails>? episodes;

  /// constructor
  DanmakuSearchEpisodesAnime({
    required this.animeId,
    required this.animeTitle,
    required this.type,
    required this.typeDescription,
    required this.episodes,
  });

  /// from json
  factory DanmakuSearchEpisodesAnime.fromJson(Map<String, dynamic> json) =>
      _$DanmakuSearchEpisodesAnimeFromJson(json);

  /// to json
  Map<String, dynamic> toJson() => _$DanmakuSearchEpisodesAnimeToJson(this);
}

/// DandanPlay 章节详情
@JsonSerializable()
class DanmakuSearchEpisodeDetails {
  /// 章节 ID
  @JsonKey(name: 'episodeId')
  final int episodeId;

  /// 章节标题
  @JsonKey(name: 'episodeTitle')
  final String? episodeTitle;

  /// constructor
  DanmakuSearchEpisodeDetails({
    required this.episodeId,
    required this.episodeTitle,
  });

  /// from json
  factory DanmakuSearchEpisodeDetails.fromJson(Map<String, dynamic> json) =>
      _$DanmakuSearchEpisodeDetailsFromJson(json);

  /// to json
  Map<String, dynamic> toJson() => _$DanmakuSearchEpisodeDetailsToJson(this);
}

/// DandanPlay 章节弹幕返回
@JsonSerializable()
class DanmakuEpisodeCommentsResponse {
  /// 弹幕总数
  @JsonKey(name: 'count')
  final int count;

  /// 弹幕列表
  @JsonKey(name: 'comments')
  final List<DanmakuEpisodeComment> comments;

  /// constructor
  DanmakuEpisodeCommentsResponse({
    required this.count,
    required this.comments,
  });

  /// from json
  factory DanmakuEpisodeCommentsResponse.fromJson(Map<String, dynamic> json) =>
      _$DanmakuEpisodeCommentsResponseFromJson(json);

  /// to json
  Map<String, dynamic> toJson() => _$DanmakuEpisodeCommentsResponseToJson(this);

  /// to BTResponse
  BTResponse<DanmakuEpisodeCommentsResponse> toBTResponse() =>
      BTResponse<DanmakuEpisodeCommentsResponse>(
          code: 0, message: 'success', data: this);
}

/// DandanPlay 章节弹幕
@JsonSerializable()
class DanmakuEpisodeComment {
  /// 弹幕 ID
  @JsonKey(name: 'cid')
  final int cid;

  /// 参数，按照 [出现时间,模式,颜色,用户ID] 的顺序
  /// 出现时间：格式为 0.00，单位为秒，精确到小数点后两位
  /// 弹幕模式：1-普通弹幕，4-底部弹幕，5-顶部弹幕
  /// 弹幕颜色：32位整数，值为 Rx256x256+Gx256+B
  /// 用户ID：通常为数字，不包含特殊字符
  @JsonKey(name: 'p')
  final String p;

  /// 内容
  @JsonKey(name: 'm')
  final String m;

  /// constructor
  DanmakuEpisodeComment({
    required this.cid,
    required this.p,
    required this.m,
  });

  /// from json
  factory DanmakuEpisodeComment.fromJson(Map<String, dynamic> json) =>
      _$DanmakuEpisodeCommentFromJson(json);

  /// to json
  Map<String, dynamic> toJson() => _$DanmakuEpisodeCommentToJson(this);
}
