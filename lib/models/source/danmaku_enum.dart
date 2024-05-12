// Package imports:
import 'package:json_annotation/json_annotation.dart';

/// 从DandanPlay开放API获取的数据枚举类
/// 详细文档参考：https://api.dandanplay.net/swagger/ui/index
/// 部分枚举类后面有对应的 extension 作为扩展方法

/// 作品类型
@JsonEnum(valueField: 'value')
enum DanmakuAnimeType {
  /// 电视连续剧
  tvSeries('tvseries'),

  /// 电视特别剧
  tvSpecial('tvspecial'),

  /// ova
  ova('ova'),

  /// 剧场版
  movie('movie'),

  /// 音乐剧
  musicVideo('musicvideo'),

  /// 网剧
  web('web'),

  /// 其他
  other('other'),

  /// 日本电影
  jpMovie('jpmovie'),

  /// 日本电视剧
  jpDrama('jpdrama'),

  /// 未知
  unknown('unknown');

  final String value;

  const DanmakuAnimeType(this.value);
}

extension DanmakuAnimeTypeExtension on DanmakuAnimeType {
  /// 获取值
}
