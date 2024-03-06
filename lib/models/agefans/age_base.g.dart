// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'age_base.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BaseBangumi _$BaseBangumiFromJson(Map<String, dynamic> json) => BaseBangumi(
      aid: json['AID'] as int,
      href: json['Href'] as String,
      newTitle: json['NewTitle'] as String,
      picSmall: json['PicSmall'] as String,
      title: json['Title'] as String,
    );

Map<String, dynamic> _$BaseBangumiToJson(BaseBangumi instance) =>
    <String, dynamic>{
      'AID': instance.aid,
      'Href': instance.href,
      'NewTitle': instance.newTitle,
      'PicSmall': instance.picSmall,
      'Title': instance.title,
    };
