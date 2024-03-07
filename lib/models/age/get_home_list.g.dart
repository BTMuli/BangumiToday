// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'get_home_list.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

HomeListResponse _$HomeListResponseFromJson(Map<String, dynamic> json) =>
    HomeListResponse(
      latest: (json['latest'] as List<dynamic>)
          .map((e) => BaseBangumi.fromJson(e as Map<String, dynamic>))
          .toList(),
      recommend: (json['recommend'] as List<dynamic>)
          .map((e) => BaseBangumi.fromJson(e as Map<String, dynamic>))
          .toList(),
      weekList: (json['week_list'] as Map<String, dynamic>).map(
        (k, e) => MapEntry(
            k,
            (e as List<dynamic>)
                .map((e) => HomeItem.fromJson(e as Map<String, dynamic>))
                .toList()),
      ),
    );

Map<String, dynamic> _$HomeListResponseToJson(HomeListResponse instance) =>
    <String, dynamic>{
      'latest': instance.latest,
      'recommend': instance.recommend,
      'week_list': instance.weekList,
    };

HomeItem _$HomeItemFromJson(Map<String, dynamic> json) => HomeItem(
      isNew: json['isnew'] as int,
      id: json['id'] as int,
      wd: json['wd'] as int,
      name: json['name'] as String,
      mTime: json['mtime'] as String,
      nameForNew: json['namefornew'] as String,
    );

Map<String, dynamic> _$HomeItemToJson(HomeItem instance) => <String, dynamic>{
      'isnew': instance.isNew,
      'id': instance.id,
      'wd': instance.wd,
      'name': instance.name,
      'mtime': instance.mTime,
      'namefornew': instance.nameForNew,
    };
