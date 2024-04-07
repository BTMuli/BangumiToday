// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'get_subject.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Subject _$SubjectFromJson(Map<String, dynamic> json) => Subject(
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
          .map((e) => SubjectTag.fromJson(e as Map<String, dynamic>))
          .toList(),
      infobox: (json['infobox'] as List<dynamic>)
          .map((e) => SubjectInfoBox.fromJson(e as Map<String, dynamic>))
          .toList(),
      rating: SubjectRating.fromJson(json['rating'] as Map<String, dynamic>),
      totalEpisodes: json['total_episodes'] as int,
      collection: BangumiCollection.fromJson(
          json['collection'] as Map<String, dynamic>),
      locked: json['locked'] as bool,
      nsfw: json['nsfw'] as bool,
    );

Map<String, dynamic> _$SubjectToJson(Subject instance) => <String, dynamic>{
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

SubjectTag _$SubjectTagFromJson(Map<String, dynamic> json) => SubjectTag(
      name: json['name'] as String,
      count: json['count'] as int,
    );

Map<String, dynamic> _$SubjectTagToJson(SubjectTag instance) =>
    <String, dynamic>{
      'name': instance.name,
      'count': instance.count,
    };

SubjectInfoBox _$SubjectInfoBoxFromJson(Map<String, dynamic> json) =>
    SubjectInfoBox(
      key: json['key'] as String,
      value: json['value'],
    );

Map<String, dynamic> _$SubjectInfoBoxToJson(SubjectInfoBox instance) =>
    <String, dynamic>{
      'key': instance.key,
      'value': instance.value,
    };

SubjectRating _$SubjectRatingFromJson(Map<String, dynamic> json) =>
    SubjectRating(
      total: json['total'] as int,
      count: Map<String, int>.from(json['count'] as Map),
      score: (json['score'] as num).toDouble(),
      rank: json['rank'] as int?,
    );

Map<String, dynamic> _$SubjectRatingToJson(SubjectRating instance) =>
    <String, dynamic>{
      'total': instance.total,
      'count': instance.count,
      'score': instance.score,
      'rank': instance.rank,
    };
