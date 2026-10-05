// Project imports:
import '../../data/parsers/rss_parser.dart';

/// Preserve the historical key until a separate, explicit key migration.
const rssItemKeyVersion = 1;

String rssItemKey(RssItem item) => '${item.title ?? ''}|${item.pubDate ?? ''}';
