import 'package:bangumi_today/models/rss/rss.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses standard RSS fields with rss_dart', () {
    var feed = RssFeed.parse('''
      <rss version="2.0">
        <channel>
          <title>Example</title>
          <link>https://example.com</link>
          <description>Example feed</description>
          <ttl>60</ttl>
          <item>
            <title>Episode 1</title>
            <link>https://example.com/1</link>
          </item>
        </channel>
      </rss>
    ''');

    expect(feed.ttl, 60);
    expect(feed.items.single.title, 'Episode 1');
    expect(feed.items.single.link, 'https://example.com/1');
  });

  test('preserves the torrent extension used by Anibt feeds', () {
    var item = RssFeed.parse('''
      <rss version="2.0">
        <channel>
          <title>Example</title>
          <link>https://example.com</link>
          <description>Example feed</description>
          <item>
            <title>Episode 1</title>
            <torrent xmlns="https://anibt.net/xmlns/0.1">
              <contentLength>1048576</contentLength>
              <magneturi>magnet:?xt=urn:btih:example</magneturi>
            </torrent>
          </item>
        </channel>
      </rss>
    ''').items.single;

    expect(item.torrent?.contentLength, 1048576);
    expect(item.torrent?.magnetUri, 'magnet:?xt=urn:btih:example');
  });
}
