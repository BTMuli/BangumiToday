import 'package:bangumi_today/core/utils/rss_date.dart';
import 'package:dart_rss/domain/dublin_core/dublin_core.dart';
import 'package:dart_rss/domain/rss_item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('returns the latest RSS item publication time', () {
    var result = latestRssPublishedAt(const [
      RssItem(pubDate: 'Mon, 27 Jul 2026 08:00:00 +0000'),
      RssItem(pubDate: '2026-07-28T12:30:00Z'),
      RssItem(pubDate: 'invalid'),
    ]);

    expect(result, DateTime.utc(2026, 7, 28, 12, 30));
  });

  test('reads the latest publication time from RSS XML', () {
    var result = latestRssPublishedAtFromXml('''
      <rss version="2.0">
        <channel>
          <title>Example</title>
          <link>https://example.com</link>
          <description>Example feed</description>
          <item><pubDate>2026-07-27T12:00:00Z</pubDate></item>
          <item><pubDate>2026-07-28T12:00:00Z</pubDate></item>
        </channel>
      </rss>
    ''');

    expect(result, DateTime.utc(2026, 7, 28, 12));
  });

  test('falls back to the Dublin Core date', () {
    var result = latestRssPublishedAt(const [
      RssItem(dc: DublinCore(date: '2026-07-28T12:00:00Z')),
    ]);

    expect(result, DateTime.utc(2026, 7, 28, 12));
  });

  test('returns null for invalid RSS data', () {
    expect(latestRssPublishedAtFromXml('not xml'), isNull);
  });
}
