import 'package:dart_rss/dart_rss.dart';
import 'package:fluent_ui/fluent_ui.dart';

/// Mikan Rss Card
class MikanRssCard extends StatelessWidget {
  /// rss item
  final RssItem item;

  /// 构造函数
  const MikanRssCard(this.item, {super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      padding: const EdgeInsets.all(12.0),
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Title: ${item.title ?? ''}'),
          Text('Description: ${item.description ?? ''}'),
          Text('Link: ${item.link ?? ''}'),
          Text('Guid: ${item.guid ?? ''}'),
          Text('PubDate: ${item.pubDate ?? ''}'),
          Text('Author: ${item.author ?? ''}'),
          Text('Source: ${item.source?.value ?? ''}'),
          Text('Content: ${item.content?.toString() ?? ''}'),
          Text('Media: ${item.media?.title?.value ?? ''}'),
          Text('资源类型: ${item.enclosure?.type ?? ''}'),
          Text('资源长度: ${item.enclosure?.length ?? ''}'),
          Text('资源链接: ${item.enclosure?.url ?? ''}'),
          Text('DublinCore: ${item.dc?.toString() ?? ''}'),
          Text('Itunes: ${item.itunes?.toString() ?? ''}'),
          Text('PodcastIndex: ${item.podcastIndex?.toString() ?? ''}'),
        ],
      ),
    );
  }
}
