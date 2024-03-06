// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'get_update.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UpdateResponse _$UpdateResponseFromJson(Map<String, dynamic> json) =>
    UpdateResponse(
      videos: (json['videos'] as List<dynamic>)
          .map((e) => BaseBangumi.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: json['total'] as int,
    );

Map<String, dynamic> _$UpdateResponseToJson(UpdateResponse instance) =>
    <String, dynamic>{
      'videos': instance.videos,
      'total': instance.total,
    };
