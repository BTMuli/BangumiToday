// Package imports:
import 'package:json_annotation/json_annotation.dart';

// Project imports:
import 'age_base.dart';

part 'get_detail.g.dart';

/// 获取番剧详细信息
/// 参考：https://github.com/ihan123/AGE/blob/master/app/src/main/kotlin/cn/xihan/age/util/Api.kt
@JsonSerializable()
class DetailResponse {
  /// video info
  @JsonKey(name: 'video')
  DetailVideo video;

  /// series info
  @JsonKey(name: 'series')
  List<BaseBangumi> series;

  /// similar
  @JsonKey(name: 'similar')
  List<BaseBangumi> similar;

  /// play_label_arr
  @JsonKey(name: 'play_label_arr')
  Map<String, String> playLabelArr;

  /// player_vip
  @JsonKey(name: 'player_vip')
  String playerVip;

  /// player_jx
  @JsonKey(name: 'player_jx')
  Map<String, String> playerJx;

  /// constructor
  DetailResponse({
    required this.video,
    required this.series,
    required this.similar,
    required this.playLabelArr,
    required this.playerVip,
    required this.playerJx,
  });

  /// from json
  factory DetailResponse.fromJson(Map<String, dynamic> json) =>
      _$DetailResponseFromJson(json);

  /// to json
  Map<String, dynamic> toJson() => _$DetailResponseToJson(this);
}

/// video info
@JsonSerializable()
class DetailVideo {
  /// anime id
  @JsonKey(name: 'id')
  int id;

  /// name other
  @JsonKey(name: 'name_other')
  String nameOther;

  /// company
  @JsonKey(name: 'company')
  String company;

  /// name
  @JsonKey(name: 'name')
  String name;

  /// type
  @JsonKey(name: 'type')
  String type;

  /// writer
  @JsonKey(name: 'writer')
  String writer;

  /// name original
  @JsonKey(name: 'name_original')
  String nameOriginal;

  /// plot
  @JsonKey(name: 'plot')
  String plot;

  /// plot arr
  @JsonKey(name: 'plot_arr')
  List<String> plotArr;

  /// play lists
  @JsonKey(name: 'play_lists')
  Map<String, List<List<String>>> playLists;

  /// area
  @JsonKey(name: 'area')
  String area;

  /// letter
  @JsonKey(name: 'letter')
  String letter;

  /// website
  @JsonKey(name: 'website')
  String website;

  /// star
  @JsonKey(name: 'star')
  int star;

  /// status
  @JsonKey(name: 'status')
  String status;

  /// up to date
  @JsonKey(name: 'uptodate')
  String upToDate;

  /// time format 1
  /// yyyyMMddHHmmss
  @JsonKey(name: 'time_format1')
  String timeFormat1;

  /// time format 2
  /// yyyy-MM-dd
  @JsonKey(name: 'time_format2')
  String timeFormat2;

  /// time format 3
  /// yyyy-MM-dd HH:mm:ss
  @JsonKey(name: 'time_format3')
  String timeFormat3;

  /// time(timestamp)
  @JsonKey(name: 'time')
  int time;

  /// tags
  @JsonKey(name: 'tags')
  String tags;

  /// tags arr
  @JsonKey(name: 'tags_arr')
  List<String> tagsArr;

  /// intro
  @JsonKey(name: 'intro')
  String intro;

  /// intro html
  @JsonKey(name: 'intro_html')
  String introHtml;

  /// intro clean
  @JsonKey(name: 'intro_clean')
  String introClean;

  /// series
  @JsonKey(name: 'series')
  String series;

  /// net_disk
  @JsonKey(name: 'net_disk')
  dynamic netDisk;

  /// resource
  @JsonKey(name: 'resource')
  String resource;

  /// year
  @JsonKey(name: 'year')
  int year;

  /// season
  @JsonKey(name: 'season')
  int season;

  /// premiere
  /// yyyy-MM-dd
  @JsonKey(name: 'premiere')
  String premiere;

  /// rank cnt
  @JsonKey(name: 'rank_cnt')
  String rankCnt;

  /// cover
  @JsonKey(name: 'cover')
  String cover;

  /// cp raid
  @JsonKey(name: 'cpraid')
  int cpRaid;

  /// comment cnt
  @JsonKey(name: 'comment_cnt')
  String commentCnt;

  /// collect cnt
  @JsonKey(name: 'collect_cnt')
  String collectCnt;

  /// constructor
  DetailVideo({
    required this.id,
    required this.nameOther,
    required this.company,
    required this.name,
    required this.type,
    required this.writer,
    required this.nameOriginal,
    required this.plot,
    required this.plotArr,
    required this.playLists,
    required this.area,
    required this.letter,
    required this.website,
    required this.star,
    required this.status,
    required this.upToDate,
    required this.timeFormat1,
    required this.timeFormat2,
    required this.timeFormat3,
    required this.time,
    required this.tags,
    required this.tagsArr,
    required this.intro,
    required this.introHtml,
    required this.introClean,
    required this.series,
    required this.netDisk,
    required this.resource,
    required this.year,
    required this.season,
    required this.premiere,
    required this.rankCnt,
    required this.cover,
    required this.cpRaid,
    required this.commentCnt,
    required this.collectCnt,
  });

  /// from json
  factory DetailVideo.fromJson(Map<String, dynamic> json) =>
      _$DetailVideoFromJson(json);

  /// to json
  Map<String, dynamic> toJson() => _$DetailVideoToJson(this);
}
