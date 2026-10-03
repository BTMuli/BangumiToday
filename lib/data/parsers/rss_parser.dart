// Package imports:
import 'package:intl/intl.dart';
import 'package:xml/xml.dart';

/// A parsed RSS 2.0 feed.
class RssFeed {
  final String? title;
  final String? link;
  final String? description;
  final String? lastBuildDate;
  final int ttl;
  final List<RssItem> items;

  const RssFeed({
    this.title,
    this.link,
    this.description,
    this.lastBuildDate,
    this.ttl = 0,
    this.items = const [],
  });

  /// Parses an RSS 2.0 feed from [xmlString].
  ///
  /// Throws a [FormatException] when the document is not valid XML or does not
  /// contain a `<channel>` element.
  factory RssFeed.parse(String xmlString) {
    XmlDocument document;
    try {
      document = XmlDocument.parse(xmlString);
    } catch (_) {
      throw FormatException('Invalid RSS XML');
    }

    var channels = document.findAllElements('channel').toList();
    if (channels.isEmpty) {
      throw FormatException('No <channel> element in feed');
    }
    var channel = channels.first;

    return RssFeed(
      title: _text(channel, 'title'),
      link: _text(channel, 'link'),
      description: _text(channel, 'description'),
      lastBuildDate: _text(channel, 'lastBuildDate'),
      ttl: int.tryParse(_text(channel, 'ttl') ?? '') ?? 0,
      items: channel
          .findElements('item', namespaceUri: '*')
          .map(RssItem.parse)
          .toList(growable: false),
    );
  }
}

/// A single `<item>` of an RSS feed.
class RssItem {
  final String? title;
  final String? description;
  final String? link;
  final String? author;
  final String? pubDate;
  final String? guid;
  final List<RssCategory> categories;
  final RssEnclosure? enclosure;
  final DublinCore? dc;

  /// Custom `<torrent>` extension used by BT sites such as AniBT.
  final RssItemTorrent? torrent;

  /// Structured release metadata from the AniBT RSS namespace.
  final RssAnibtMetadata? anibt;

  const RssItem({
    this.title,
    this.description,
    this.link,
    this.author,
    this.pubDate,
    this.guid,
    this.categories = const [],
    this.enclosure,
    this.dc,
    this.torrent,
    this.anibt,
  });

  factory RssItem.parse(XmlElement element) {
    var torrent = RssItemTorrent.parse(element);
    return RssItem(
      title: _text(element, 'title'),
      description: _text(element, 'description'),
      link: _text(element, 'link'),
      author: _text(element, 'author'),
      // Mikan puts the publish time inside its <torrent> extension instead of
      // a direct <item><pubDate>, so fall back to the torrent value.
      pubDate: _text(element, 'pubDate') ?? torrent.pubDate,
      guid: _text(element, 'guid'),
      categories: element
          .findElements('category', namespaceUri: '*')
          .map(RssCategory.parse)
          .toList(growable: false),
      enclosure: _enclosure(element),
      dc: _dublinCore(element),
      torrent: torrent,
      anibt: RssAnibtMetadata.parse(element),
    );
  }
}

/// AniBT's namespaced release fields, separate from generic RSS metadata.
class RssAnibtMetadata {
  static const namespaceUri = 'https://anibt.net/xmlns/rss/1.0/';

  final String? releasePageUrl;
  final String? torrentUrl;
  final int? bgmId;
  final String? animeTitle;
  final String? animeTitleEnglish;
  final String? releaseTitle;
  final String? episode;
  final String? episodeKey;
  final String? version;
  final String? groupName;
  final String? groupSlug;
  final String? resolution;
  final List<String> languages;
  final String? subtitle;
  final String? format;
  final int? fileSize;
  final List<String> customTags;

  const RssAnibtMetadata({
    this.releasePageUrl,
    this.torrentUrl,
    this.bgmId,
    this.animeTitle,
    this.animeTitleEnglish,
    this.releaseTitle,
    this.episode,
    this.episodeKey,
    this.version,
    this.groupName,
    this.groupSlug,
    this.resolution,
    this.languages = const [],
    this.subtitle,
    this.format,
    this.fileSize,
    this.customTags = const [],
  });

  /// Display keys can describe batches or specials as well as numeric episodes.
  String? get episodeLabel {
    var key = episodeKey ?? episode;
    if (key == null || key.trim().isEmpty) return null;
    key = key.trim();
    if (key.toUpperCase() == 'BATCH') return '合集';
    if (RegExp(r'^\d+(?:\.\d+)?(?:-\d+(?:\.\d+)?)?$').hasMatch(key)) {
      return '第 $key 集';
    }
    return key;
  }

  static RssAnibtMetadata? parse(XmlElement itemElement) {
    var fields = itemElement.childElements
        .where((element) => element.namespaceUri == namespaceUri)
        .toList(growable: false);
    if (fields.isEmpty) return null;

    List<String> values(String name) => fields
        .where((element) => element.localName == name)
        .map((element) => element.innerText.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);

    String? value(String name) => values(name).firstOrNull;

    return RssAnibtMetadata(
      releasePageUrl: value('releasePageUrl'),
      torrentUrl: value('torrentUrl'),
      bgmId: int.tryParse(value('bgmId') ?? ''),
      animeTitle: value('animeTitle'),
      animeTitleEnglish: value('animeTitleEnglish'),
      releaseTitle: value('releaseTitle'),
      episode: value('episode'),
      episodeKey: value('episodeKey'),
      version: value('version'),
      groupName: value('groupName'),
      groupSlug: value('groupSlug'),
      resolution: value('resolution'),
      languages: values('language'),
      subtitle: value('subtitle'),
      format: value('format'),
      fileSize: int.tryParse(value('fileSize') ?? ''),
      customTags: values('customTag'),
    );
  }
}

/// An `<enclosure>` element of an RSS item.
class RssEnclosure {
  final String? url;
  final String? type;
  final int length;

  const RssEnclosure({this.url, this.type, this.length = 0});
}

/// A `<category>` element of an RSS item.
class RssCategory {
  final String? value;
  final String? domain;

  const RssCategory({this.value, this.domain});

  factory RssCategory.parse(XmlElement element) {
    return RssCategory(
      value: element.innerText,
      domain: element.getAttribute('domain'),
    );
  }
}

/// Dublin Core metadata of an RSS item.
class DublinCore {
  final String? date;

  const DublinCore({this.date});
}

/// The `<torrent>` extension used by BT aggregation feeds.
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
    XmlElement? torrentElement;
    for (var element in itemElement.childElements) {
      if (element.localName == 'torrent') {
        torrentElement = element;
        break;
      }
    }
    if (torrentElement == null) return const RssItemTorrent();

    var torrent = torrentElement;
    String? value(String name) {
      for (var element in torrent.childElements) {
        if (element.localName.toLowerCase() == name.toLowerCase()) {
          return element.innerText;
        }
      }
      return null;
    }

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

/// Returns the text of the first direct child element with the local
/// [name], ignoring namespaces, or `null` when absent.
String? _text(XmlElement element, String name) {
  return element.getElement(name, namespaceUri: '*')?.innerText;
}

/// Parses the first `<enclosure>` direct child of [element].
RssEnclosure? _enclosure(XmlElement element) {
  var enclosure = element.getElement('enclosure', namespaceUri: '*');
  if (enclosure == null) return null;
  return RssEnclosure(
    url: enclosure.getAttribute('url'),
    length: int.tryParse(enclosure.getAttribute('length') ?? '') ?? 0,
    type: enclosure.getAttribute('type'),
  );
}

/// Parses Dublin Core metadata from the direct children of [element].
DublinCore? _dublinCore(XmlElement element) {
  var date = element.getElement('date', namespaceUri: '*')?.innerText;
  if (date == null) return null;
  return DublinCore(date: date);
}

/// Safe date parsing helper kept for compatibility with RSS date handling.
extension SafeParseDateTime on DateTime {
  static DateTime? safeParse(String? str) {
    if (str == null) return null;
    const dateFormatPatterns = ['EEE, d MMM yyyy HH:mm:ss Z'];
    try {
      return DateTime.parse(str);
    } catch (_) {
      for (var pattern in dateFormatPatterns) {
        try {
          var format = DateFormat(pattern);
          return format.parse(str);
        } catch (_) {}
      }
    }
    return null;
  }
}
