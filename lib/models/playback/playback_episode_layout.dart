/// 选集面板的排版方式。默认网格，列表用于显示每个文件的更多信息。
enum PlaybackEpisodeLayout {
  grid('网格', '集数平铺，一屏显示更多条目'),
  list('列表', '每行一集，显示集数与文件名');

  const PlaybackEpisodeLayout(this.label, this.description);

  final String label;
  final String description;

  static PlaybackEpisodeLayout parse(String? value) =>
      values.where((layout) => layout.name == value).firstOrNull ?? grid;
}
