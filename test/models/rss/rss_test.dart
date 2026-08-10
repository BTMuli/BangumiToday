// Package imports:
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:bangumi_today/models/rss/rss.dart';

void main() {
  test('parses standard RSS fields', () {
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

  test('parses enclosure, categories and Dublin Core', () {
    var item = RssFeed.parse('''
      <rss version="2.0" xmlns:dc="http://purl.org/dc/elements/1.1/">
        <channel>
          <title>Example</title>
          <link>https://example.com</link>
          <description>Example feed</description>
          <item>
            <title>Episode 1</title>
            <link>https://example.com/1</link>
            <category domain="https://example.com/genres">Anime</category>
            <enclosure
              url="https://example.com/1.torrent"
              length="2048"
              type="application/x-bittorrent" />
            <dc:date>2026-07-28T12:00:00Z</dc:date>
          </item>
        </channel>
      </rss>
    ''').items.single;

    expect(item.categories.single.value, 'Anime');
    expect(item.categories.single.domain, 'https://example.com/genres');
    expect(item.enclosure?.url, 'https://example.com/1.torrent');
    expect(item.enclosure?.length, 2048);
    expect(item.enclosure?.type, 'application/x-bittorrent');
    expect(item.dc?.date, '2026-07-28T12:00:00Z');
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

  test('matches torrent fields case-insensitively for Mikan feeds', () {
    var item = RssFeed.parse('''
      <rss version="2.0">
        <channel>
          <title>Example</title>
          <link>https://example.com</link>
          <description>Example feed</description>
          <item>
            <title>Episode 1</title>
            <torrent xmlns="http://mikanani.me/0.1/">
              <contentLength>2097152</contentLength>
              <magnetURI>magnet:?xt=urn:btih:mikan</magnetURI>
              <infoHash>mikan-hash</infoHash>
              <fileName>Episode 1.mkv</fileName>
            </torrent>
          </item>
        </channel>
      </rss>
    ''').items.single;

    expect(item.torrent?.contentLength, 2097152);
    expect(item.torrent?.magnetUri, 'magnet:?xt=urn:btih:mikan');
    expect(item.torrent?.infohash, 'mikan-hash');
    expect(item.torrent?.filename, 'Episode 1.mkv');
  });

  test('falls back to the torrent pubDate used by Mikan feeds', () {
    var item = RssFeed.parse('''
      <rss version="2.0">
        <channel>
          <title>Example</title>
          <link>https://example.com</link>
          <description>Example feed</description>
          <item>
            <title>Episode 1</title>
            <torrent xmlns="http://mikanani.me/0.1/">
              <contentLength>2097152</contentLength>
              <magnetURI>magnet:?xt=urn:btih:mikan</magnetURI>
              <infoHash>mikan-hash</infoHash>
              <fileName>Episode 1.mkv</fileName>
              <pubDate>2026-08-09T22:00:46.303812</pubDate>
            </torrent>
          </item>
        </channel>
      </rss>
    ''').items.single;

    expect(item.pubDate, '2026-08-09T22:00:46.303812');
  });

  test('prefers the direct item pubDate over the torrent pubDate', () {
    var item = RssFeed.parse('''
      <rss version="2.0">
        <channel>
          <title>Example</title>
          <link>https://example.com</link>
          <description>Example feed</description>
          <item>
            <title>Episode 1</title>
            <pubDate>2026-08-01T12:00:00Z</pubDate>
            <torrent xmlns="http://mikanani.me/0.1/">
              <pubDate>2026-08-09T22:00:46.303812</pubDate>
            </torrent>
          </item>
        </channel>
      </rss>
    ''').items.single;

    expect(item.pubDate, '2026-08-01T12:00:00Z');
  });
}
