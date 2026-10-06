enum _SubtitleLanguage {
  simplified('简体中文'),
  traditional('繁体中文'),
  chinese('中文'),
  english('英语'),
  japanese('日语');

  const _SubtitleLanguage(this.label);

  final String label;
}

String _normalizeLanguage(String value) =>
    value.trim().toLowerCase().replaceAll('_', '-');

/// Fansubs also use sc/tc and chs/cht as language metadata.
_SubtitleLanguage? _subtitleLanguageCode(String value) {
  var code = _normalizeLanguage(value);
  switch (code) {
    case 'sc':
    case 'chs':
    case 'hans':
    case 'cn':
    case 'simplified':
      return _SubtitleLanguage.simplified;
    case 'tc':
    case 'cht':
    case 'hant':
    case 'tw':
    case 'hk':
    case 'traditional':
      return _SubtitleLanguage.traditional;
  }
  // Filenames and descriptive titles are not bare language codes.
  if (RegExp(r'^[a-z]{2,3}(?:-[a-z]{2,4}|-\d{3})*$').hasMatch(code)) {
    var tags = code.split('-');
    if (const ['zh', 'zho', 'chi', 'cmn', 'yue'].contains(tags.first)) {
      // Script is more specific than region (e.g. zh-Hant-CN).
      if (tags.any(const ['hans', 'chs', 'sc'].contains)) {
        return _SubtitleLanguage.simplified;
      }
      if (tags.any(const ['hant', 'cht', 'tc'].contains)) {
        return _SubtitleLanguage.traditional;
      }
      if (tags.any(const ['cn', 'sg'].contains)) {
        return _SubtitleLanguage.simplified;
      }
      if (tags.any(const ['tw', 'hk', 'mo'].contains)) {
        return _SubtitleLanguage.traditional;
      }
      return _SubtitleLanguage.chinese;
    }
    if (const ['en', 'eng'].contains(tags.first)) {
      return _SubtitleLanguage.english;
    }
    if (const ['ja', 'jpn', 'jp'].contains(tags.first)) {
      return _SubtitleLanguage.japanese;
    }
  }
  return switch (code) {
    '简体中文' ||
    '简体' ||
    '简中' ||
    '簡體中文' ||
    '簡體' ||
    '簡中' ||
    '简' ||
    '簡' => _SubtitleLanguage.simplified,
    '繁体中文' ||
    '繁体' ||
    '繁中' ||
    '繁體中文' ||
    '繁體' ||
    '繁' => _SubtitleLanguage.traditional,
    'chinese' || '中文' || '汉语' || '漢語' => _SubtitleLanguage.chinese,
    'english' || '英文' || '英语' || '英語' => _SubtitleLanguage.english,
    'japanese' || '日文' || '日语' || '日語' => _SubtitleLanguage.japanese,
    _ => null,
  };
}

_SubtitleLanguage? _subtitleTitleLanguage(String value) {
  var name = _normalizeLanguage(value);
  var bare = _subtitleLanguageCode(name);
  if (bare != null) return bare;
  bool named(String pattern) => RegExp(pattern).hasMatch(name);
  bool word(String pattern) => named('(^|[^a-z0-9])($pattern)([^a-z0-9]|\$)');
  var bilingual = r'(?:[+-]?(?:jp|jpn|ja|en|eng))?';
  if (named('[简簡](?:体|體|中|日|英)') ||
      word('hans|(?:chs|sc)$bilingual|gb|gbk|gb2312|simplified')) {
    return _SubtitleLanguage.simplified;
  }
  if (named('繁(?:体|體|中|日|英)') ||
      word('hant|(?:cht|tc)$bilingual|big5|traditional')) {
    return _SubtitleLanguage.traditional;
  }
  var chineseCode = r'(?:zh|zho|chi|cmn|yue)-';
  if (word('$chineseCode(?:cn|sg)')) {
    return _SubtitleLanguage.simplified;
  }
  if (word('$chineseCode(?:tw|hk|mo)')) {
    return _SubtitleLanguage.traditional;
  }
  if (named('中文|中字|汉语|漢語|中[日英]|[日英]中') || word('chinese|chi|zho|zh|cmn|yue')) {
    return _SubtitleLanguage.chinese;
  }
  if (named('英文|英[语語]') || word('english|eng|en')) {
    return _SubtitleLanguage.english;
  }
  if (named('日文|日[语語]') || word('japanese|jpn|ja|jp')) {
    return _SubtitleLanguage.japanese;
  }
  return null;
}

_SubtitleLanguage? _subtitleLanguage({String? language, String? title}) {
  var code = _subtitleTitleLanguage(language ?? '');
  // Trust explicit script metadata; generic chi/zh needs the fansub title.
  if (code == _SubtitleLanguage.simplified ||
      code == _SubtitleLanguage.traditional) {
    return code;
  }
  var named = _subtitleTitleLanguage(title ?? '');
  if (named == _SubtitleLanguage.simplified ||
      named == _SubtitleLanguage.traditional) {
    return named;
  }
  if (code == _SubtitleLanguage.chinese || named == _SubtitleLanguage.chinese) {
    return _SubtitleLanguage.chinese;
  }
  return code ?? named;
}

/// Simplified, Traditional, unspecified Chinese, English, then Japanese.
int? playbackSubtitlePriority({String? language, String? title}) =>
    _subtitleLanguage(language: language, title: title)?.index;

typedef PlaybackSubtitleMetadata = ({
  String id,
  String? title,
  String? language,
  bool? isDefault,
});

/// Ignore pseudo tracks; prefer default tracks only within a language tier.
String preferredPlaybackSubtitle(Iterable<PlaybackSubtitleMetadata> tracks) {
  var selected = 'no';
  int? priority;
  var selectedDefault = false;
  for (var track in tracks) {
    if (track.id == 'auto' || track.id == 'no') continue;
    var candidate = playbackSubtitlePriority(
      language: track.language,
      title: track.title,
    );
    var isDefault = track.isDefault ?? false;
    if (candidate != null &&
        (priority == null ||
            candidate < priority ||
            (candidate == priority && isDefault && !selectedDefault))) {
      selected = track.id;
      priority = candidate;
      selectedDefault = isDefault;
    }
  }
  return selected;
}

/// Put the language first, with filenames/descriptions on a separate line.
({String title, String? description}) playbackSubtitleLabel(
  String id,
  String? title,
  String? language,
) {
  if (id == 'auto') return (title: '自动选择', description: null);
  if (id == 'no') return (title: '关闭', description: null);
  var name = (title ?? '').trim();
  var lang = (language ?? '').trim();
  var inferred = _subtitleLanguage(language: lang, title: name);
  var label = inferred?.label;
  if (label == null &&
      lang.isNotEmpty &&
      !const ['und', 'unknown', 'none'].contains(lang.toLowerCase())) {
    label = lang;
  }
  label ??= '轨道 $id';
  var translatedName = _subtitleLanguageCode(name)?.label ?? name;
  return (
    title: label,
    description:
        name.isEmpty || translatedName.toLowerCase() == label.toLowerCase()
        ? null
        : name,
  );
}

/// Compact representation for the video information overlay.
String playbackSubtitleTrackLabel(String id, String? title, String? language) {
  var label = playbackSubtitleLabel(id, title, language);
  return [label.title, ?label.description].join(' · ');
}
