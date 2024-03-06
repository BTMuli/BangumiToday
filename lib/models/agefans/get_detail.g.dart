// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'get_detail.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DetailResponse _$DetailResponseFromJson(Map<String, dynamic> json) =>
    DetailResponse(
      video: DetailVideo.fromJson(json['video'] as Map<String, dynamic>),
      series: (json['series'] as List<dynamic>)
          .map((e) => BaseBangumi.fromJson(e as Map<String, dynamic>))
          .toList(),
      similar: (json['similar'] as List<dynamic>)
          .map((e) => BaseBangumi.fromJson(e as Map<String, dynamic>))
          .toList(),
      playLabelArr: Map<String, String>.from(json['play_label_arr'] as Map),
      playerVip: json['player_vip'] as String,
      playerJx: Map<String, String>.from(json['player_jx'] as Map),
    );

Map<String, dynamic> _$DetailResponseToJson(DetailResponse instance) =>
    <String, dynamic>{
      'video': instance.video,
      'series': instance.series,
      'similar': instance.similar,
      'play_label_arr': instance.playLabelArr,
      'player_vip': instance.playerVip,
      'player_jx': instance.playerJx,
    };

DetailVideo _$DetailVideoFromJson(Map<String, dynamic> json) => DetailVideo(
      id: json['id'] as int,
      nameOther: json['name_other'] as String,
      company: json['company'] as String,
      name: json['name'] as String,
      type: json['type'] as String,
      writer: json['writer'] as String,
      nameOriginal: json['name_original'] as String,
      plot: json['plot'] as String,
      plotArr:
          (json['plot_arr'] as List<dynamic>).map((e) => e as String).toList(),
      playLists: (json['play_lists'] as Map<String, dynamic>).map(
        (k, e) => MapEntry(
            k,
            (e as List<dynamic>)
                .map((e) =>
                    (e as List<dynamic>).map((e) => e as String).toList())
                .toList()),
      ),
      area: json['area'] as String,
      letter: json['letter'] as String,
      website: json['website'] as String,
      star: json['star'] as int,
      status: json['status'] as String,
      upToDate: json['uptodate'] as String,
      timeFormat1: json['time_format1'] as String,
      timeFormat2: json['time_format2'] as String,
      timeFormat3: json['time_format3'] as String,
      time: json['time'] as int,
      tags: json['tags'] as String,
      tagsArr:
          (json['tags_arr'] as List<dynamic>).map((e) => e as String).toList(),
      intro: json['intro'] as String,
      introHtml: json['intro_html'] as String,
      introClean: json['intro_clean'] as String,
      series: json['series'] as String,
      netDisk: json['net_disk'],
      resource: json['resource'] as String,
      year: json['year'] as int,
      season: json['season'] as int,
      premiere: json['premiere'] as String,
      rankCnt: json['rank_cnt'] as String,
      cover: json['cover'] as String,
      cpRaid: json['cpraid'] as int,
      commentCnt: json['comment_cnt'] as String,
      collectCnt: json['collect_cnt'] as String,
    );

Map<String, dynamic> _$DetailVideoToJson(DetailVideo instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name_other': instance.nameOther,
      'company': instance.company,
      'name': instance.name,
      'type': instance.type,
      'writer': instance.writer,
      'name_original': instance.nameOriginal,
      'plot': instance.plot,
      'plot_arr': instance.plotArr,
      'play_lists': instance.playLists,
      'area': instance.area,
      'letter': instance.letter,
      'website': instance.website,
      'star': instance.star,
      'status': instance.status,
      'uptodate': instance.upToDate,
      'time_format1': instance.timeFormat1,
      'time_format2': instance.timeFormat2,
      'time_format3': instance.timeFormat3,
      'time': instance.time,
      'tags': instance.tags,
      'tags_arr': instance.tagsArr,
      'intro': instance.intro,
      'intro_html': instance.introHtml,
      'intro_clean': instance.introClean,
      'series': instance.series,
      'net_disk': instance.netDisk,
      'resource': instance.resource,
      'year': instance.year,
      'season': instance.season,
      'premiere': instance.premiere,
      'rank_cnt': instance.rankCnt,
      'cover': instance.cover,
      'cpraid': instance.cpRaid,
      'comment_cnt': instance.commentCnt,
      'collect_cnt': instance.collectCnt,
    };
