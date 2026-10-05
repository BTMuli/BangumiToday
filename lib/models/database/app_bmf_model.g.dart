// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_bmf_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AppBmfModel _$AppBmfModelFromJson(Map<String, dynamic> json) => AppBmfModel(
  id: (json['id'] as num?)?.toInt() ?? -1,
  subject: (json['subject'] as num).toInt(),
  title: json['title'] as String?,
  airDate: json['airDate'] as String?,
  download: json['download'] as String?,
  subscriptions: (json['subscriptions'] as List<dynamic>?)
      ?.map((e) => AppSubscriptionModel.fromJson(e as Map<String, dynamic>))
      .toList(),
);

Map<String, dynamic> _$AppBmfModelToJson(AppBmfModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'subject': instance.subject,
      'title': instance.title,
      'airDate': instance.airDate,
      'download': instance.download,
      'subscriptions': instance.subscriptions.map((e) => e.toJson()).toList(),
    };
