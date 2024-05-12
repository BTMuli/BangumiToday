// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'request_danmaku.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DanmakuSearchAnimeResponse _$DanmakuSearchAnimeResponseFromJson(
        Map<String, dynamic> json) =>
    DanmakuSearchAnimeResponse(
      list: (json['animes'] as List<dynamic>?)
          ?.map((e) =>
              DanmakuSearchAnimeDetails.fromJson(e as Map<String, dynamic>))
          .toList(),
      errorCode: (json['errorCode'] as num).toInt(),
      success: json['success'] as bool,
      errorMessage: json['errorMessage'] as String?,
    );

Map<String, dynamic> _$DanmakuSearchAnimeResponseToJson(
        DanmakuSearchAnimeResponse instance) =>
    <String, dynamic>{
      'animes': instance.list?.map((e) => e.toJson()).toList(),
      'errorCode': instance.errorCode,
      'success': instance.success,
      'errorMessage': instance.errorMessage,
    };

DanmakuSearchAnimeDetails _$DanmakuSearchAnimeDetailsFromJson(
        Map<String, dynamic> json) =>
    DanmakuSearchAnimeDetails(
      animeId: (json['animeId'] as num).toInt(),
      animeTitle: json['animeTitle'] as String?,
      type: $enumDecode(_$DanmakuAnimeTypeEnumMap, json['type']),
      typeDescription: json['typeDescription'] as String?,
      imageUrl: json['imageUrl'] as String?,
      startDate: json['startDate'] as String,
      episodeCount: (json['episodeCount'] as num).toInt(),
      rating: (json['rating'] as num).toDouble(),
      isFavorited: json['isFavorited'] as bool,
    );

Map<String, dynamic> _$DanmakuSearchAnimeDetailsToJson(
        DanmakuSearchAnimeDetails instance) =>
    <String, dynamic>{
      'animeId': instance.animeId,
      'animeTitle': instance.animeTitle,
      'type': _$DanmakuAnimeTypeEnumMap[instance.type]!,
      'typeDescription': instance.typeDescription,
      'imageUrl': instance.imageUrl,
      'startDate': instance.startDate,
      'episodeCount': instance.episodeCount,
      'rating': instance.rating,
      'isFavorited': instance.isFavorited,
    };

const _$DanmakuAnimeTypeEnumMap = {
  DanmakuAnimeType.tvSeries: 'tvseries',
  DanmakuAnimeType.tvSpecial: 'tvspecial',
  DanmakuAnimeType.ova: 'ova',
  DanmakuAnimeType.movie: 'movie',
  DanmakuAnimeType.musicVideo: 'musicvideo',
  DanmakuAnimeType.web: 'web',
  DanmakuAnimeType.other: 'other',
  DanmakuAnimeType.jpMovie: 'jpmovie',
  DanmakuAnimeType.jpDrama: 'jpdrama',
  DanmakuAnimeType.unknown: 'unknown',
};

DanmakuSearchEpisodesResponse _$DanmakuSearchEpisodesResponseFromJson(
        Map<String, dynamic> json) =>
    DanmakuSearchEpisodesResponse(
      hasMore: json['hasMore'] as bool,
      animes: (json['animes'] as List<dynamic>?)
          ?.map((e) =>
              DanmakuSearchEpisodesAnime.fromJson(e as Map<String, dynamic>))
          .toList(),
      errorCode: (json['errorCode'] as num).toInt(),
      success: json['success'] as bool,
      errorMessage: json['errorMessage'] as String?,
    );

Map<String, dynamic> _$DanmakuSearchEpisodesResponseToJson(
        DanmakuSearchEpisodesResponse instance) =>
    <String, dynamic>{
      'hasMore': instance.hasMore,
      'animes': instance.animes,
      'errorCode': instance.errorCode,
      'success': instance.success,
      'errorMessage': instance.errorMessage,
    };

DanmakuSearchEpisodesAnime _$DanmakuSearchEpisodesAnimeFromJson(
        Map<String, dynamic> json) =>
    DanmakuSearchEpisodesAnime(
      animeId: (json['animeId'] as num).toInt(),
      animeTitle: json['animeTitle'] as String?,
      type: $enumDecode(_$DanmakuAnimeTypeEnumMap, json['type']),
      typeDescription: json['typeDescription'] as String?,
      episodes: (json['episodes'] as List<dynamic>?)
          ?.map((e) =>
              DanmakuSearchEpisodeDetails.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$DanmakuSearchEpisodesAnimeToJson(
        DanmakuSearchEpisodesAnime instance) =>
    <String, dynamic>{
      'animeId': instance.animeId,
      'animeTitle': instance.animeTitle,
      'type': _$DanmakuAnimeTypeEnumMap[instance.type]!,
      'typeDescription': instance.typeDescription,
      'episodes': instance.episodes,
    };

DanmakuSearchEpisodeDetails _$DanmakuSearchEpisodeDetailsFromJson(
        Map<String, dynamic> json) =>
    DanmakuSearchEpisodeDetails(
      episodeId: (json['episodeId'] as num).toInt(),
      episodeTitle: json['episodeTitle'] as String?,
    );

Map<String, dynamic> _$DanmakuSearchEpisodeDetailsToJson(
        DanmakuSearchEpisodeDetails instance) =>
    <String, dynamic>{
      'episodeId': instance.episodeId,
      'episodeTitle': instance.episodeTitle,
    };

DanmakuEpisodeCommentsResponse _$DanmakuEpisodeCommentsResponseFromJson(
        Map<String, dynamic> json) =>
    DanmakuEpisodeCommentsResponse(
      count: (json['count'] as num).toInt(),
      comments: (json['comments'] as List<dynamic>)
          .map((e) => DanmakuEpisodeComment.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$DanmakuEpisodeCommentsResponseToJson(
        DanmakuEpisodeCommentsResponse instance) =>
    <String, dynamic>{
      'count': instance.count,
      'comments': instance.comments,
    };

DanmakuEpisodeComment _$DanmakuEpisodeCommentFromJson(
        Map<String, dynamic> json) =>
    DanmakuEpisodeComment(
      cid: (json['cid'] as num).toInt(),
      p: json['p'] as String,
      m: json['m'] as String,
    );

Map<String, dynamic> _$DanmakuEpisodeCommentToJson(
        DanmakuEpisodeComment instance) =>
    <String, dynamic>{
      'cid': instance.cid,
      'p': instance.p,
      'm': instance.m,
    };
