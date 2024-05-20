/// 资源相关模型定义
class BtSource {
  /// 资源名称
  String? name;

  /// 章节
  List<BtSourceEp> episodes;

  /// 构造
  BtSource({this.name, required this.episodes});
}

/// 查找结果
class BtSourceFind {
  /// source
  String source;

  /// 动画名称
  String anime;

  /// 章节id，用于各适配器匹配
  String series;

  /// 描述
  String? desc;

  /// 图片
  String? image;

  /// 构造
  BtSourceFind(this.source, this.series, this.anime, {this.desc, this.image});

  /// toString
  @override
  String toString() {
    return '[BtSourceFind][$source] - $anime\n'
        '[image] - $image\n'
        '[series] - $series\n'
        '[desc] - $desc\n';
  }
}

/// 章节
class BtSourceEp {
  /// 章节id，用于说明集数
  num id;

  /// 章节标识，用于获取播放链接
  String? episode;

  /// 章节标题
  String? title;

  /// 构造
  BtSourceEp(this.id, {this.episode, this.title});
}
