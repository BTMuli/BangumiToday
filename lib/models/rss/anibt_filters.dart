// Project imports:
import 'rss.dart';

enum AnibtTagKind { resolution, language, subtitle, format }

class AnibtTagSelection {
  final AnibtTagKind kind;
  final String value;

  const AnibtTagSelection(this.kind, this.value);
}

enum AnibtSortField {
  publishedAt('发布时间', 'publishedAt'),
  fileSize('文件大小', 'fileSize'),
  episode('集数', null);

  const AnibtSortField(this.label, this.rssField);

  final String label;
  final String? rssField;
}

/// Server-supported RSS filters and filters applied to its returned items.
class AnibtFilters {
  static const defaultLanguages = {'CHS', 'CHT'};
  static const resolutions = ['4K', '2160p', '1080p', '720p', '480p', '360p'];
  static const languageLabels = {
    'CHS': '简中',
    'CHT': '繁中',
    'JP': '日语',
    'EN': '英语',
    'KO': '韩语',
    'ES': '西班牙语',
    'PT': '葡萄牙语',
    'FR': '法语',
    'DE': '德语',
    'IT': '意大利语',
    'RU': '俄语',
    'AR': '阿拉伯语',
    'HI': '印地语',
    'ID': '印尼语',
    'MS': '马来语',
    'TH': '泰语',
    'VI': '越南语',
    'TL': '菲律宾语',
    'TR': '土耳其语',
    'PL': '波兰语',
    'UK': '乌克兰语',
  };
  static const subtitleLabels = {
    'EXTERNAL': '外挂字幕',
    'INTERNAL': '内封字幕',
    'EMBEDDED': '内嵌字幕',
    'NONE': '无字幕',
  };
  static const formats = ['MKV', 'MP4', 'AVI', 'WEBM'];

  final String query;
  final Set<String> selectedResolutions;
  final Set<String> selectedLanguages;
  final Set<String> selectedSubtitles;
  final Set<String> selectedFormats;
  final AnibtSortField sortField;
  final bool descending;

  AnibtFilters({
    this.query = '',
    Set<String> selectedResolutions = const {},
    Set<String> selectedLanguages = defaultLanguages,
    Set<String> selectedSubtitles = const {},
    Set<String> selectedFormats = const {},
    this.sortField = AnibtSortField.publishedAt,
    this.descending = true,
  }) : selectedResolutions = Set.unmodifiable(selectedResolutions),
       selectedLanguages = Set.unmodifiable(selectedLanguages),
       selectedSubtitles = Set.unmodifiable(selectedSubtitles),
       selectedFormats = Set.unmodifiable(selectedFormats);

  int get tagCount =>
      selectedResolutions.length +
      selectedLanguages.length +
      selectedSubtitles.length +
      selectedFormats.length;

  bool get isDefault =>
      query.trim().isEmpty &&
      selectedResolutions.isEmpty &&
      selectedLanguages.length == defaultLanguages.length &&
      selectedLanguages.containsAll(defaultLanguages) &&
      selectedSubtitles.isEmpty &&
      selectedFormats.isEmpty &&
      sortField == AnibtSortField.publishedAt &&
      descending;

  bool get usesLocalResults =>
      selectedSubtitles.isNotEmpty || sortField == AnibtSortField.episode;

  Set<String> _valuesFor(AnibtTagKind kind) => switch (kind) {
    AnibtTagKind.resolution => selectedResolutions,
    AnibtTagKind.language => selectedLanguages,
    AnibtTagKind.subtitle => selectedSubtitles,
    AnibtTagKind.format => selectedFormats,
  };

  bool includesTag(AnibtTagSelection tag) =>
      _valuesFor(tag.kind).contains(tag.value);

  AnibtFilters toggleTag(AnibtTagSelection tag) {
    var values = Set<String>.of(_valuesFor(tag.kind));
    if (!values.remove(tag.value)) values.add(tag.value);
    return switch (tag.kind) {
      AnibtTagKind.resolution => copyWith(selectedResolutions: values),
      AnibtTagKind.language => copyWith(selectedLanguages: values),
      AnibtTagKind.subtitle => copyWith(selectedSubtitles: values),
      AnibtTagKind.format => copyWith(selectedFormats: values),
    };
  }

  List<String> get labels => [
    if (query.trim().isNotEmpty) '搜索：${query.trim()}',
    ...selectedResolutions,
    ...selectedLanguages.map((value) => languageLabels[value] ?? value),
    ...selectedSubtitles.map((value) => subtitleLabels[value] ?? value),
    ...selectedFormats,
    '${sortField.label} ${descending ? '↓' : '↑'}',
  ];

  AnibtFilters copyWith({
    String? query,
    Set<String>? selectedResolutions,
    Set<String>? selectedLanguages,
    Set<String>? selectedSubtitles,
    Set<String>? selectedFormats,
    AnibtSortField? sortField,
    bool? descending,
  }) => AnibtFilters(
    query: query ?? this.query,
    selectedResolutions: selectedResolutions ?? this.selectedResolutions,
    selectedLanguages: selectedLanguages ?? this.selectedLanguages,
    selectedSubtitles: selectedSubtitles ?? this.selectedSubtitles,
    selectedFormats: selectedFormats ?? this.selectedFormats,
    sortField: sortField ?? this.sortField,
    descending: descending ?? this.descending,
  );

  /// Lists must be encoded as repeated keys, not brackets or comma-separated.
  Map<String, dynamic> get queryParameters => {
    if (query.trim().isNotEmpty) 'q': query.trim(),
    if (selectedResolutions.isNotEmpty)
      'resolution': selectedResolutions.toList()..sort(),
    if (selectedLanguages.isNotEmpty)
      'language': selectedLanguages.toList()..sort(),
    if (selectedFormats.isNotEmpty) 'format': selectedFormats.toList()..sort(),
    if (sortField.rssField != null && sortField != AnibtSortField.publishedAt)
      'sortField': sortField.rssField,
    // Episode sorting operates on the latest matching RSS result window.
    if (!descending && sortField != AnibtSortField.episode) 'sortOrder': 'asc',
  };

  List<RssItem> applyLocal(Iterable<RssItem> items) {
    var filtered = items.where(
      (item) =>
          selectedSubtitles.isEmpty ||
          selectedSubtitles.contains(item.anibt?.subtitle?.toUpperCase()),
    );
    if (sortField != AnibtSortField.episode) return filtered.toList();

    return _sort(filtered, _episodeNumber);
  }

  /// Keep the latest RSS window usable if AniBT's search backend is down.
  List<RssItem> applyToFeedWindow(Iterable<RssItem> items) {
    var words = query.trim().toLowerCase().split(RegExp(r'\s+'));
    var filtered = items.where((item) {
      var metadata = item.anibt;
      var text = [
        item.title,
        item.torrent?.filename,
        metadata?.animeTitle,
        metadata?.animeTitleEnglish,
        metadata?.releaseTitle,
        metadata?.groupName,
        ...?metadata?.customTags,
      ].whereType<String>().join('\n').toLowerCase();
      return words.every(text.contains) &&
          (selectedResolutions.isEmpty ||
              selectedResolutions.contains(metadata?.resolution)) &&
          (selectedLanguages.isEmpty ||
              (metadata?.languages.any(
                    (value) => selectedLanguages.contains(value.toUpperCase()),
                  ) ??
                  false)) &&
          (selectedFormats.isEmpty ||
              selectedFormats.contains(metadata?.format?.toUpperCase()));
    });
    var result = applyLocal(filtered);
    return switch (sortField) {
      AnibtSortField.episode => result,
      AnibtSortField.fileSize => _sort(result, _fileSize),
      AnibtSortField.publishedAt => _sort(result, _publishedAt),
    };
  }

  List<RssItem> _sort(
    Iterable<RssItem> items,
    double? Function(RssItem) value,
  ) {
    var indexed = items.indexed.toList()
      ..sort((a, b) {
        var aValue = value(a.$2);
        var bValue = value(b.$2);
        if (aValue == null && bValue != null) return 1;
        if (aValue != null && bValue == null) return -1;
        var comparison = aValue == null || bValue == null
            ? 0
            : aValue.compareTo(bValue);
        if (comparison == 0) return a.$1.compareTo(b.$1);
        return descending ? -comparison : comparison;
      });
    return indexed.map((entry) => entry.$2).toList();
  }

  static double? _fileSize(RssItem item) {
    for (var size in [
      item.anibt?.fileSize,
      item.torrent?.contentLength,
      item.enclosure?.length,
    ]) {
      if (size != null && size > 0) return size.toDouble();
    }
    return null;
  }

  static double? _publishedAt(RssItem item) {
    for (var text in [item.torrent?.pubDate, item.pubDate, item.dc?.date]) {
      var date = SafeParseDateTime.safeParse(text);
      if (date != null) return date.millisecondsSinceEpoch.toDouble();
    }
    return null;
  }

  static double? _episodeNumber(RssItem item) {
    var key = item.anibt?.episodeKey ?? item.anibt?.episode ?? '';
    var match = RegExp(
      r'^(\d+(?:\.\d+)?)(?:-\d+(?:\.\d+)?)?$',
    ).firstMatch(key.trim());
    return double.tryParse(match?.group(1) ?? '');
  }
}
