// Project imports:
import '../../models/rss/rss.dart';

bool rssRefreshDue({
  required DateTime now,
  DateTime? lastUpdated,
  DateTime? lastAttempt,
  Duration interval = const Duration(minutes: 5),
}) {
  // Failed requests also wait before retrying, including when a tab reopens.
  for (var at in [lastUpdated, lastAttempt]) {
    if (at != null) {
      var age = now.difference(at);
      if (!age.isNegative && age < interval) return false;
    }
  }
  return true;
}

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
