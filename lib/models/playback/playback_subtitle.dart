/// Language metadata is often only `chi`; fansub titles carry the script.
int? playbackSubtitlePriority({String? language, String? title}) {
  var lang = (language ?? '').trim().toLowerCase().replaceAll('_', '-');
  var name = (title ?? '').toLowerCase();
  var tags = lang.split('-');
  bool named(String pattern) => RegExp(pattern).hasMatch(name);
  bool word(String pattern) => named('(^|[^a-z0-9])($pattern)([^a-z0-9]|\$)');
  var chinese = const ['zh', 'zho', 'chi', 'cmn', 'yue'].contains(tags.first);
  if ((chinese && tags.any(const ['hans', 'chs', 'cn', 'sg'].contains)) ||
      lang == 'chs' ||
      named('[简簡]') ||
      word('hans|chs|sc|gb|simplified')) {
    return 0;
  }
  if ((chinese && tags.any(const ['hant', 'cht', 'tw', 'hk', 'mo'].contains)) ||
      lang == 'cht' ||
      named('繁') ||
      word('hant|cht|tc|big5|traditional')) {
    return 1;
  }
  // Unspecified Chinese follows explicitly identified Simplified/Traditional.
  if (chinese || named('中文|中字|中日|中英') || word('chinese|chi|zho|zh')) {
    return 2;
  }
  if (const ['en', 'eng'].contains(tags.first) ||
      named('英文|英[语語]') ||
      word('english|eng|en')) {
    return 3;
  }
  if (const ['ja', 'jpn', 'jp'].contains(tags.first) ||
      named('日文|日[语語]') ||
      word('japanese|jpn|ja|jp')) {
    return 4;
  }
  return null;
}

typedef PlaybackSubtitleMetadata = ({
  String id,
  String? title,
  String? language,
});

/// Ignore mpv's pseudo tracks and preserve track order for equal priorities.
String preferredPlaybackSubtitle(Iterable<PlaybackSubtitleMetadata> tracks) {
  var selected = 'no';
  int? priority;
  for (var track in tracks) {
    if (track.id == 'auto' || track.id == 'no') continue;
    var candidate = playbackSubtitlePriority(
      language: track.language,
      title: track.title,
    );
    if (candidate != null && (priority == null || candidate < priority)) {
      selected = track.id;
      priority = candidate;
    }
  }
  return selected;
}

/// Translate bare language codes while preserving descriptive track titles.
String _subtitleLanguageLabel(String value) =>
    switch (playbackSubtitlePriority(language: value)) {
      0 => '简体中文',
      1 => '繁体中文',
      2 => '中文',
      3 => '英语',
      4 => '日语',
      _ => value,
    };

String playbackSubtitleTrackLabel(String id, String? title, String? language) {
  if (id == 'auto') return '自动选择';
  if (id == 'no') return '关闭';
  var name = (title ?? '').trim();
  var lang = (language ?? '').trim();
  var labels = <String>[];
  if (name.isNotEmpty) labels.add(_subtitleLanguageLabel(name));
  if (lang.isNotEmpty) {
    var label = _subtitleLanguageLabel(lang);
    if (!labels.any((value) => value.toLowerCase() == label.toLowerCase())) {
      labels.add(label);
    }
  }
  return labels.isEmpty ? '轨道 $id' : labels.join(' · ');
}
