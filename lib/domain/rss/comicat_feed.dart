/// Comicat 提供独立 RSS 的资源分类。
enum ComicatRssCategory {
  all('全部', ''),
  anime('动画', '1'),
  raw('Raw', '6'),
  movie('OVA / 剧场版', 'animovie'),
  complete('合集', 'complete');

  final String label;
  final String rssId;

  const ComicatRssCategory(this.label, this.rssId);
}

/// 分类和全站搜索分别使用站点对应的 RSS 地址。
class ComicatFeed {
  final ComicatRssCategory category;
  final List<String> keywords;

  const ComicatFeed.category([this.category = ComicatRssCategory.all])
    : keywords = const [];

  ComicatFeed.search(String query)
    : category = ComicatRssCategory.all,
      keywords = List.unmodifiable(
        query.split(RegExp(r'[\s+]+')).where((keyword) => keyword.isNotEmpty),
      );

  bool get isSearch => keywords.isNotEmpty;

  String get query => keywords.join(' ');

  String get path {
    if (isSearch) {
      var terms = keywords.map(Uri.encodeComponent).join('+');
      return '/rss-$terms.xml';
    }
    return category == ComicatRssCategory.all
        ? '/rss.xml'
        : '/rss-${category.rssId}.xml';
  }
}
