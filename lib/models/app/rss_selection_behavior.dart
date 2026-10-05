/// 搜索选中 RSS 时，如何处理番剧已有的订阅。
enum RssSelectionBehavior {
  replace('替换'),
  add('新增');

  const RssSelectionBehavior(this.label);

  final String label;

  static RssSelectionBehavior fromConfig(String? value) =>
      values.where((behavior) => behavior.name == value).firstOrNull ?? replace;
}
