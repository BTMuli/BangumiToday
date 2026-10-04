/// 播放器窗口的置顶策略。窗口是否真的置顶由当前播放状态决定。
enum PlaybackOnTop {
  off('关闭', '不置顶，与其他窗口同等层级'),
  playing('播放时置顶', '播放中显示在其他窗口之上，暂停后恢复'),
  always('始终置顶', '无论是否播放都显示在其他窗口之上');

  const PlaybackOnTop(this.label, this.description);

  final String label;
  final String description;

  /// 是否要求窗口置顶；[playing] 还要等播放状态满足。
  bool get pinned => this != off;

  PlaybackOnTop get next => switch (this) {
    off => playing,
    playing => always,
    always => off,
  };

  static PlaybackOnTop parse(String? value) =>
      values.where((mode) => mode.name == value).firstOrNull ?? off;
}
