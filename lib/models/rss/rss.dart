import 'package:rss_dart/dart_rss.dart' as rss;
import 'package:xml/xml.dart';

export 'package:rss_dart/dart_rss.dart' hide RssFeed, RssItem;
export 'package:rss_dart/domain/dublin_core/dublin_core.dart';

class RssFeed {
  final rss.RssFeed _feed;
  final List<RssItem> items;

  RssFeed._(this._feed, this.items);

  factory RssFeed.parse(String xmlString) {
    var feed = rss.RssFeed.parse(xmlString);
    var document = XmlDocument.parse(xmlString);
    var itemElements = document
        .findAllElements('channel')
        .first
        .findElements('item')
        .toList();
    var items = <RssItem>[];

    for (var index = 0; index < feed.items.length; index++) {
      var element = index < itemElements.length ? itemElements[index] : null;
      items.add(RssItem._from(feed.items[index], element));
    }

    return RssFeed._(feed, items);
  }

  int get ttl => _feed.ttl;
}

class RssItem extends rss.RssItem {
  final RssItemTorrent? torrent;

  const RssItem({
    super.title,
    super.description,
    super.link,
    super.pubDate,
    super.author,
    super.dc,
    this.torrent,
  });

  RssItem._from(rss.RssItem item, XmlElement? element)
    : torrent = element == null ? null : RssItemTorrent.parse(element),
      super(
        title: item.title,
        description: item.description,
        link: item.link,
        categories: item.categories,
        guid: item.guid,
        pubDate: item.pubDate,
        author: item.author,
        comments: item.comments,
        source: item.source,
        content: item.content,
        media: item.media,
        enclosure: item.enclosure,
        dc: item.dc,
        itunes: item.itunes,
        podcastIndex: item.podcastIndex,
        podlove: item.podlove,
      );
}

class RssItemTorrent {
  final String? link;
  final int? contentLength;
  final String? pubDate;
  final String? infohash;
  final String? magnetUri;
  final String? filename;

  const RssItemTorrent({
    this.link,
    this.contentLength,
    this.pubDate,
    this.infohash,
    this.magnetUri,
    this.filename,
  });

  factory RssItemTorrent.parse(XmlElement itemElement) {
    var torrentElement = itemElement.childElements
        .where((element) => element.localName == 'torrent')
        .firstOrNull;
    if (torrentElement == null) return const RssItemTorrent();

    String? value(String name) => torrentElement.childElements
        .where((element) => element.localName == name)
        .firstOrNull
        ?.innerText;

    return RssItemTorrent(
      link: value('link'),
      contentLength: int.tryParse(value('contentLength') ?? ''),
      pubDate: value('pubDate'),
      infohash: value('infohash'),
      magnetUri: value('magneturi'),
      filename: value('filename'),
    );
  }
}
