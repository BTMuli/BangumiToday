// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_bmf_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AppBmfModel _$AppBmfModelFromJson(Map<String, dynamic> json) => AppBmfModel(
      id: (json['id'] as num?)?.toInt() ?? -1,
      subject: (json['subject'] as num).toInt(),
      title: json['title'] as String?,
      rss: json['rss'] as String?,
      download: json['download'] as String?,
      mkBgmId: json['mkBgmId'] as String?,
      mkGroupId: json['mkGroupId'] as String?,
    );

Map<String, dynamic> _$AppBmfModelToJson(AppBmfModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'subject': instance.subject,
      'title': instance.title,
      'rss': instance.rss,
      'mkBgmId': instance.mkBgmId,
      'mkGroupId': instance.mkGroupId,
      'download': instance.download,
    };
