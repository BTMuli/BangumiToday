// Package imports:
import 'package:json_annotation/json_annotation.dart';

part 'mikan_model.g.dart';

/// 蜜柑计划搜索结果
@JsonSerializable()
class MikanSearchItemModel {
  /// 标题
  final String title;

  /// 链接
  final String link;

  /// 封面
  final String cover;

  /// ID
  final String id;

  /// rss
  final String rss;

  /// 构造函数
  MikanSearchItemModel({
    required this.title,
    required this.link,
    required this.cover,
    required this.id,
    required this.rss,
  });

  /// 反序列化
  factory MikanSearchItemModel.fromJson(Map<String, dynamic> json) =>
      _$MikanSearchItemModelFromJson(json);

  /// 序列化
  Map<String, dynamic> toJson() => _$MikanSearchItemModelToJson(this);
}

/// 蜜柑计划番剧详情页中的单个资源
class MikanEpisodeModel {
  /// 资源标题
  final String title;

  /// 资源详情页链接
  final String link;

  /// 磁力链接
  final String magnet;

  /// 种子下载链接
  final String? torrent;

  /// 大小（站点展示文本）
  final String? size;

  /// 更新时间（站点展示文本）
  final String? updatedAt;

  /// 构造函数
  const MikanEpisodeModel({
    required this.title,
    required this.link,
    required this.magnet,
    this.torrent,
    this.size,
    this.updatedAt,
  });
}

/// 蜜柑计划番剧的字幕组
class MikanGroupModel {
  /// 字幕组 ID
  final String id;

  /// 字幕组名称
  final String name;

  /// 最近更新时间（站点展示文本）
  final String? updatedAt;

  /// 字幕组 RSS
  final String rss;

  /// 详情页首屏展示的最近资源
  final List<MikanEpisodeModel> items;

  /// 构造函数
  const MikanGroupModel({
    required this.id,
    required this.name,
    required this.rss,
    this.updatedAt,
    this.items = const [],
  });

  /// 补充资源列表
  MikanGroupModel withItems(List<MikanEpisodeModel> value) {
    return MikanGroupModel(
      id: id,
      name: name,
      rss: rss,
      updatedAt: updatedAt,
      items: value,
    );
  }
}

/// 蜜柑计划番剧详情
class MikanBangumiDetailModel {
  /// 蜜柑计划番剧 ID
  final String id;

  /// 关联的 Bangumi 条目 ID
  final int? bgmId;

  /// 字幕组列表
  final List<MikanGroupModel> groups;

  /// 构造函数
  const MikanBangumiDetailModel({
    required this.id,
    required this.groups,
    this.bgmId,
  });
}
