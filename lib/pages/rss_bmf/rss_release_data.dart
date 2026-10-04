// Package imports:
import 'package:html/parser.dart' as html;

// Project imports:
import '../../core/utils/tool_func.dart';
import '../../models/rss/rss.dart';

enum RssReleaseSource { mikan, comicat }

/// 展示层投影：保留完整标题，仅从明确的返回字段和标题标记提取辅助信息。
class RssReleaseData {
  final RssItem item;
  final String title;
  final List<String> categories;
  final List<String> tags;
  final String? author;
  final String? imageUrl;
  final String? summary;
  final String? sizeLabel;
  final DateTime? publishedAt;
  final String? downloadUrl;
  final String? detailUrl;

  const RssReleaseData({
    required this.item,
    required this.title,
    required this.categories,
    required this.tags,
    this.author,
    this.imageUrl,
    this.summary,
    this.sizeLabel,
    this.publishedAt,
    this.downloadUrl,
    this.detailUrl,
  });

  String get key => item.guid ?? detailUrl ?? downloadUrl ?? title;

  bool get canDownload => downloadUrl != null && _text(item.title) != null;

  factory RssReleaseData.fromItem(RssItem item, RssReleaseSource source) {
    var title = replaceEscape(item.title ?? '').trim();
    var categories = item.categories
        .map((category) => _text(category.value))
        .whereType<String>()
        .toSet()
        .toList();
    var description = html.parseFragment(item.description ?? '');
    var detailUrl = _httpUrl(item.link) ?? _httpUrl(item.torrent?.link);
    String? imageUrl;
    if (source == RssReleaseSource.comicat) {
      for (var image in description.querySelectorAll('img')) {
        var src = _text(image.attributes['src']);
        if (src == null ||
            image.attributes['width'] == '1' ||
            image.attributes['height'] == '1') {
          continue;
        }
        var imageUri = Uri.tryParse(src);
        if (imageUri == null) continue;
        var resolved = Uri.tryParse(
          detailUrl ?? '',
        )?.resolveUri(imageUri).toString();
        imageUrl = _httpUrl(resolved ?? src);
        if (imageUrl != null) break;
      }
    }
    var bytes = item.enclosure?.length;
    if (bytes == null || bytes <= 0) bytes = item.torrent?.contentLength;
    var descriptionText = (description.text ?? '').trim();
    var sizeMatch = RegExp(
      r'\[\s*(\d+(?:\.\d+)?\s*(?:[KMGT]i?B|B))\s*\]\s*$',
      caseSensitive: false,
    ).firstMatch(descriptionText);
    var sizeLabel = bytes != null && bytes > 0
        ? filesize(bytes)
        : sizeMatch?.group(1);
    var summary = descriptionText.replaceAll(RegExp(r'\s+'), ' ');
    if (summary.startsWith(title)) summary = summary.substring(title.length);
    if (sizeMatch != null) {
      summary = summary.replaceFirst(sizeMatch.group(0)!, '').trim();
    }
    var enclosureUrl = _text(item.enclosure?.url);
    var magnet =
        _magnetUrl(enclosureUrl) ?? _magnetUrl(item.torrent?.magnetUri);
    var torrentUrl = _httpUrl(enclosureUrl);
    var torrentType = item.enclosure?.type?.toLowerCase() ?? '';
    if (!torrentType.contains('bittorrent') &&
        !(Uri.tryParse(torrentUrl ?? '')?.path.endsWith('.torrent') ?? false)) {
      torrentUrl = null;
    }
    return RssReleaseData(
      item: item,
      title: title.isEmpty ? '未命名资源' : title,
      categories: categories,
      tags: _titleTags(title),
      author: _text(item.author),
      imageUrl: imageUrl,
      summary: _text(summary),
      sizeLabel: sizeLabel,
      publishedAt: parseDate(item.pubDate) ?? parseDate(item.dc?.date),
      downloadUrl: torrentUrl ?? magnet,
      detailUrl: detailUrl,
    );
  }

  bool matches(String query) {
    var text = [
      title,
      author ?? '',
      ...categories,
      ...tags,
    ].join(' ').toLowerCase();
    return query
        .trim()
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .every(text.contains);
  }

  static List<String> _titleTags(String title) {
    var tags = <String>{};
    var resolution = RegExp(
      r'\b(?:\d{3,4}[pi]|4K|8K|\d{3,4}[x×]\d{3,4})\b',
      caseSensitive: false,
    ).firstMatch(title)?.group(0);
    if (resolution != null) tags.add(resolution.toUpperCase());
    var format = RegExp(
      r'\b(?:WEB-DL|WEBRip|BDRip|BluRay|BD|FLAC|MP3|WAV)\b',
      caseSensitive: false,
    ).firstMatch(title)?.group(0);
    if (format != null) tags.add(format.toUpperCase());
    var subtitle = RegExp(
      r'简繁|簡繁|简中|簡中|繁中|简体|簡體|繁体|繁體|'
      r'双语|雙語|无字幕|無字幕|外挂|外掛|内嵌|內嵌',
    ).allMatches(title).map((match) => match.group(0)!);
    tags.addAll(subtitle.take(2));
    return tags.toList();
  }

  /// Mikan 的 ISO 时间与 Comicat 的 RFC 822 时间，后者保留时区偏移。
  static DateTime? parseDate(String? raw) {
    var value = _text(raw);
    if (value == null) return null;
    var iso = DateTime.tryParse(value);
    if (iso != null) return iso;
    var match = RegExp(
      r'^(?:\w{3},\s*)?(\d{1,2})\s+(\w{3})\s+(\d{4})\s+'
      r'(\d{2}):(\d{2}):(\d{2})\s+([+-]\d{4}|GMT|UTC)$',
      caseSensitive: false,
    ).firstMatch(value);
    if (match == null) return null;
    const months = [
      'jan',
      'feb',
      'mar',
      'apr',
      'may',
      'jun',
      'jul',
      'aug',
      'sep',
      'oct',
      'nov',
      'dec',
    ];
    var month = months.indexOf(match[2]!.toLowerCase()) + 1;
    if (month == 0) return null;
    var day = int.parse(match[1]!);
    var hour = int.parse(match[4]!);
    var minute = int.parse(match[5]!);
    var second = int.parse(match[6]!);
    var date = DateTime.utc(
      int.parse(match[3]!),
      month,
      day,
      hour,
      minute,
      second,
    );
    if (date.month != month ||
        date.day != day ||
        hour > 23 ||
        minute > 59 ||
        second > 59) {
      return null;
    }
    var zone = match[7]!;
    var offset = 0;
    if (zone.startsWith('+') || zone.startsWith('-')) {
      var hours = int.parse(zone.substring(1, 3));
      var minutes = int.parse(zone.substring(3, 5));
      if (hours > 23 || minutes > 59) return null;
      offset = (hours * 60 + minutes) * (zone.startsWith('-') ? -1 : 1);
    }
    return date.subtract(Duration(minutes: offset));
  }

  static String? _text(String? value) {
    var text = value?.trim();
    return text == null || text.isEmpty ? null : text;
  }

  static String? _httpUrl(String? value) {
    var text = _text(value);
    var uri = text == null ? null : Uri.tryParse(text);
    return uri != null &&
            (uri.scheme == 'http' || uri.scheme == 'https') &&
            uri.host.isNotEmpty
        ? text
        : null;
  }

  static String? _magnetUrl(String? value) {
    var text = _text(value);
    return Uri.tryParse(text ?? '')?.scheme == 'magnet' ? text : null;
  }
}

/// 按发布时间从新到旧；相同时间保留返回顺序，缺失时间置后。
List<RssReleaseData> filterRssReleases(
  List<RssReleaseData> releases, {
  String query = '',
  String? category,
}) {
  var result = releases.indexed.where((entry) {
    return entry.$2.matches(query) &&
        (category == null || entry.$2.categories.contains(category));
  }).toList();
  result.sort((a, b) {
    var aDate = a.$2.publishedAt;
    var bDate = b.$2.publishedAt;
    var comparison = aDate == null
        ? (bDate == null ? 0 : 1)
        : bDate == null
        ? -1
        : bDate.compareTo(aDate);
    return comparison != 0 ? comparison : a.$1.compareTo(b.$1);
  });
  return result.map((entry) => entry.$2).toList();
}
