import '../../models/rss/rss.dart';

DateTime? latestRssPublishedAt(Iterable<RssItem> items) {
  DateTime? latest;
  for (var item in items) {
    var publishedAt =
        SafeParseDateTime.safeParse(item.pubDate) ??
        SafeParseDateTime.safeParse(item.dc?.date);
    if (publishedAt != null &&
        (latest == null || publishedAt.isAfter(latest))) {
      latest = publishedAt;
    }
  }
  return latest;
}

DateTime? latestRssPublishedAtFromXml(String data) {
  if (data.isEmpty) return null;
  try {
    return latestRssPublishedAt(RssFeed.parse(data).items);
  } catch (_) {
    return null;
  }
}
