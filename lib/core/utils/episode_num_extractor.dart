enum EpisodeNumberKind { single, ambiguous, batch, special, seasonal, unknown }

class EpisodeNumberResult {
  const EpisodeNumberResult(
    this.kind, {
    this.number,
    this.evidence,
    this.season,
  });

  final EpisodeNumberKind kind;
  final double? number;
  final String? evidence;

  /// Only explicit season/episode pairs imply season-relative numbering.
  /// A season in the title alone can still accompany an absolute episode.
  final int? season;

  String get reason => switch (kind) {
    EpisodeNumberKind.single => '明确的单集编号',
    EpisodeNumberKind.ambiguous => '文件名存在多个集数候选',
    EpisodeNumberKind.batch => '合集文件不能对应单个章节',
    EpisodeNumberKind.special => '特别篇或不明确的编号需要手动选择章节',
    EpisodeNumberKind.seasonal => '文件名只有季信息，没有可靠的单集编号',
    EpisodeNumberKind.unknown => '文件名没有可靠的单集编号',
  };
}

// Dots before resolution tokens separate release metadata, not decimals.
final _resolutionPattern = RegExp(
  r'(?<![A-Za-z0-9])(?:360|480|576|720|1080|1440|2160|4320)[pi]'
  r'(?![A-Za-z0-9])',
  caseSensitive: false,
);
final _batchPattern = RegExp(
  r'\b(?:BATCH|COMPLETE)\b|合集|全集|'
  r'(?:\bEP?\s*)?\d{1,4}(?:\.\d+)?(?:v\d+)?\s*[-+~～至]\s*'
  r'(?:EP?\s*)?\d{1,4}(?:\.\d+)?',
  caseSensitive: false,
);
final _specialPattern = RegExp(
  r'(?<![A-Za-z0-9])(?:SP|OVA|OAD|(?:NC)?(?:OP|ED)|PV|CM|MENU|MENUS|'
  r'EXTRA|EXTRAS|BONUS|CREDITLESS|TRAILER|TEASER|PREVIEW|SAMPLE)'
  r'(?:\d+)?(?![A-Za-z0-9])|特别篇|特別篇|特典|预告|預告|予告|菜单|菜單',
  caseSensitive: false,
);
final _extraDirectoryPattern = RegExp(
  r'^(?:MENU|MENUS|EXTRAS?|BONUS|CREDITLESS|TRAILERS?|TEASERS?|'
  r'PREVIEWS?|SAMPLES?|(?:NC)?OP(?:[ &+_-]*(?:NC)?ED)?|(?:NC)?ED|PV|CM|'
  r'特典|菜单|菜單|预告|預告|予告)$',
  caseSensitive: false,
);
final _fractionalSpecialPattern = RegExp(
  r'(?<![A-Za-z0-9])SP[ ._-]*(\d{1,4}\.\d*[1-9]\d*)(?:v\d+)?'
  r'(?![\dA-Za-z]|\.\d)',
  caseSensitive: false,
);
final _unparsedFractionalPattern = RegExp(
  r'(?:S\d{1,2}[ ._-]*E|\d{1,2}x|\b(?:Episode|EP?)[ ._-]*|'
  r'第\s*|^|[\s\[【_-])\d+\.\d+(?:v\d+)?'
  r'(?=[话話集\s\[\]【】()._-]|$)',
  caseSensitive: false,
);
final _seasonEpisodePatterns = [
  RegExp(
    r'(?<![A-Za-z0-9])S(\d{1,2})[ ._-]*E'
    r'(\d{1,4}(?:\.\d+)?)(?:v\d+)?(?![\dA-Za-z]|\.\d)',
    caseSensitive: false,
  ),
  RegExp(
    r'(?<![A-Za-z0-9])(\d{1,2})x'
    r'(\d{1,4}(?:\.\d+)?)(?:v\d+)?(?![\dA-Za-z]|\.\d)',
    caseSensitive: false,
  ),
];
final _seasonPattern = RegExp(
  r'(?<![A-Za-z0-9])(?:S\d{1,2}(?!\d)|'
  r'Season[ ._-]*\d{1,2}(?!\d)|'
  r'\d{1,2}(?:st|nd|rd|th)[ ._-]+Season\b)|'
  r'第\s*[0-9〇零一二三四五六七八九十百两兩]+\s*[季期]',
  caseSensitive: false,
);
final _episodePatterns = [
  RegExp(
    r'(?<![A-Za-z0-9])(?:Episode|EP?)[ ._-]*'
    r'(\d{1,4}(?:\.\d+)?)(?:v\d+)?(?![\dA-Za-z]|\.\d)',
    caseSensitive: false,
  ),
  RegExp(
    r'(?<![\d.])(?:第\s*)?(\d{1,4}(?:\.\d+)?)(?:v\d+)?\s*[话話集]',
    caseSensitive: false,
  ),
  RegExp(
    r'(?:\s-\s*|\s—\s*)(\d{1,4}(?:\.\d+)?)(?:v\d+)?'
    r'(?=$|[\s\[【(])',
    caseSensitive: false,
  ),
  RegExp(
    r'\[\s*(\d{1,4}(?:\.\d+)?)(?:v\d+)?\s*\]|'
    r'【\s*(\d{1,4}(?:\.\d+)?)(?:v\d+)?\s*】',
    caseSensitive: false,
  ),
  _fractionalSpecialPattern,
  RegExp(
    r'(?:^|[\s_-])(\d{1,4}\.\d+)(?:v\d+)?'
    r'(?=$|[\s\[\]【】()_-])',
    caseSensitive: false,
  ),
];

/// Extra filenames and dedicated extra directories never imply a chapter.
/// Collection/season names in parent directories are not episode evidence.
bool isPlaybackExtra(String filePath) {
  var parts = filePath.split(RegExp(r'[/\\]'));
  var name = parts.last
      .replaceFirst(RegExp(r'\.[A-Za-z0-9]+$'), '')
      .replaceAll(_resolutionPattern, ' ');
  // SP13.5 can identify a numbered recap; other extras need a manual link.
  return _specialPattern.hasMatch(
        name.replaceAll(_fractionalSpecialPattern, ' '),
      ) ||
      parts
          .take(parts.length - 1)
          .any((part) => _extraDirectoryPattern.hasMatch(part.trim()));
}

/// Conservative filename evidence; display labels are not mapping evidence.
EpisodeNumberResult extractEpisodeNumber(String filePath) {
  var name = filePath.split(RegExp(r'[/\\]')).last;
  name = name
      .replaceFirst(RegExp(r'\.[A-Za-z0-9]+$'), '')
      .replaceAll(_resolutionPattern, ' ');
  if (isPlaybackExtra(filePath)) {
    return const EpisodeNumberResult(EpisodeNumberKind.special);
  }
  if (_batchPattern.hasMatch(name.replaceAll(_seasonPattern, ' '))) {
    return const EpisodeNumberResult(EpisodeNumberKind.batch);
  }
  var candidates = <double, String>{};
  var seasons = <int>{};
  var hasSeason = _seasonPattern.hasMatch(name);
  var invalidPair = false;
  for (var pattern in _seasonEpisodePatterns) {
    name = name.replaceAllMapped(pattern, (match) {
      hasSeason = true;
      var season = int.parse(match[1]!);
      var number = double.parse(match[2]!);
      if (season <= 0 || number <= 0) {
        invalidPair = true;
      } else {
        seasons.add(season);
        candidates[number] = match[0]!;
      }
      return ' ';
    });
  }
  // Strip title season markers before scanning ordinary episode numbers.
  name = name.replaceAll(_seasonPattern, ' ');
  for (var pattern in _episodePatterns) {
    name = name.replaceAllMapped(pattern, (match) {
      var number = double.parse(match[1] ?? match[2]!);
      if (number <= 0 ||
          (number >= 1900 && number <= 2099) ||
          {360, 480, 576, 720, 1080, 1440, 2160, 4320}.contains(number)) {
        return match[0]!;
      }
      candidates[number] = match.group(0)!;
      return ' ';
    });
  }
  // Keep unsupported fractional markers from falling back to an integer
  // candidate or the unnumbered single-chapter inference.
  if (_unparsedFractionalPattern.hasMatch(name)) {
    return const EpisodeNumberResult(EpisodeNumberKind.special);
  }
  if (invalidPair || seasons.length > 1 || candidates.length > 1) {
    return const EpisodeNumberResult(EpisodeNumberKind.ambiguous);
  }
  if (candidates.isEmpty) {
    return EpisodeNumberResult(
      hasSeason ? EpisodeNumberKind.seasonal : EpisodeNumberKind.unknown,
    );
  }
  return EpisodeNumberResult(
    EpisodeNumberKind.single,
    number: candidates.keys.single,
    evidence: candidates.values.single,
    season: seasons.singleOrNull,
  );
}
