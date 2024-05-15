// Package imports:
import 'package:media_kit_video/media_kit_video.dart';

// Project imports:
import 'source_model.dart';

/// 资源匹配状态枚举
enum SourceMatchStat {
  /// 未匹配
  none,

  /// 匹配中
  matching,

  /// 匹配成功
  matched,

  /// 匹配失败
  failed,
}

/// 资源基类
abstract class BtSourceBase {
  /// 资源名称
  String name;

  /// 资源描述
  String? description;

  /// 匹配状态
  SourceMatchStat status = SourceMatchStat.none;

  /// 构造
  BtSourceBase(this.name, {this.description});

  /// 查找，提供 [title] 和 [keyword]，返回是否匹配成功
  /// [title] 数据来源于 bangumi.tv，[keyword] 为手动输入
  Future<List<BtSourceFind>> search(String title, String keyword);

  /// 获取资源，提供 [series]，返回列表
  Future<List<BtSource>> load(String series);

  /// 播放，提供 [episode]和控制器[controller]
  Future<void> play(String episode, VideoController controller);
}
