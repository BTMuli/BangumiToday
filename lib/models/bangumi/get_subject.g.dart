// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'get_subject.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BangumiSubject _$BangumiSubjectFromJson(Map<String, dynamic> json) =>
    BangumiSubject(
      id: json['id'] as int,
      type: json['type'] as int,
      platform: json['platform'] as String,
      name: json['name'] as String,
      nameCn: json['name_cn'] as String,
      summary: json['summary'] as String,
      date: json['date'] as String,
      images: BangumiImage.fromJson(json['images'] as Map<String, dynamic>),
      eps: json['eps'] as int,
      volumes: json['volumes'] as int,
      tags: (json['tags'] as List<dynamic>)
          .map((e) => BangumiSubjectTag.fromJson(e as Map<String, dynamic>))
          .toList(),
      infobox: (json['infobox'] as List<dynamic>)
          .map((e) => BangumiSubjectInfoBox.fromJson(e as Map<String, dynamic>))
          .toList(),
      rating:
          BangumiSubjectRating.fromJson(json['rating'] as Map<String, dynamic>),
      totalEpisodes: json['total_episodes'] as int,
      collection: BangumiCollection.fromJson(
          json['collection'] as Map<String, dynamic>),
      locked: json['locked'] as bool,
      nsfw: json['nsfw'] as bool,
    );

Map<String, dynamic> _$BangumiSubjectToJson(BangumiSubject instance) =>
    <String, dynamic>{
      'id': instance.id,
      'type': instance.type,
      'platform': instance.platform,
      'name': instance.name,
      'name_cn': instance.nameCn,
      'summary': instance.summary,
      'date': instance.date,
      'images': instance.images,
      'eps': instance.eps,
      'volumes': instance.volumes,
      'tags': instance.tags,
      'infobox': instance.infobox,
      'rating': instance.rating,
      'total_episodes': instance.totalEpisodes,
      'collection': instance.collection,
      'locked': instance.locked,
      'nsfw': instance.nsfw,
    };

BangumiSubjectTag _$BangumiSubjectTagFromJson(Map<String, dynamic> json) =>
    BangumiSubjectTag(
      name: json['name'] as String,
      count: json['count'] as int,
    );

Map<String, dynamic> _$BangumiSubjectTagToJson(BangumiSubjectTag instance) =>
    <String, dynamic>{
      'name': instance.name,
      'count': instance.count,
    };

BangumiSubjectInfoBox _$BangumiSubjectInfoBoxFromJson(
        Map<String, dynamic> json) =>
    BangumiSubjectInfoBox(
      key: json['key'] as String,
      value: json['value'],
    );

Map<String, dynamic> _$BangumiSubjectInfoBoxToJson(
        BangumiSubjectInfoBox instance) =>
    <String, dynamic>{
      'key': instance.key,
      'value': instance.value,
    };

BangumiSubjectRating _$BangumiSubjectRatingFromJson(
        Map<String, dynamic> json) =>
    BangumiSubjectRating(
      total: json['total'] as int,
      count: Map<String, int>.from(json['count'] as Map),
      score: (json['score'] as num).toDouble(),
      rank: json['rank'] as int?,
    );

Map<String, dynamic> _$BangumiSubjectRatingToJson(
        BangumiSubjectRating instance) =>
    <String, dynamic>{
      'total': instance.total,
      'count': instance.count,
      'score': instance.score,
      'rank': instance.rank,
    };
