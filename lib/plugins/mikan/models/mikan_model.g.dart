// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mikan_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MikanSearchItemModel _$MikanSearchItemModelFromJson(
        Map<String, dynamic> json) =>
    MikanSearchItemModel(
      title: json['title'] as String,
      link: json['link'] as String,
      cover: json['cover'] as String,
      id: json['id'] as String,
      rss: json['rss'] as String,
    );

Map<String, dynamic> _$MikanSearchItemModelToJson(
        MikanSearchItemModel instance) =>
    <String, dynamic>{
      'title': instance.title,
      'link': instance.link,
      'cover': instance.cover,
      'id': instance.id,
      'rss': instance.rss,
    };
