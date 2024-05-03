// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'request_episode.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BangumiEpisodeListResp _$BangumiEpisodeListRespFromJson(
        Map<String, dynamic> json) =>
    BangumiEpisodeListResp(
      code: (json['code'] as num).toInt(),
      message: json['message'] as String,
      data: BangumiPageT<BangumiEpisode>.fromJson(
          json['data'] as Map<String, dynamic>,
          (value) => BangumiEpisode.fromJson(value as Map<String, dynamic>)),
    );
