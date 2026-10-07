/// Filename numbering for display and playback order only.
/// Bangumi chapter matching keeps its separate, conservative evidence rules.
class PlaybackEpisodeNumber {
  const PlaybackEpisodeNumber({
    required this.number,
    required this.start,
    this.season,
  });

  final double number;
  final int? season;
  final int start;

  String get label => number == number.truncateToDouble()
      ? number.toInt().toString()
      : number.toString();

  int compareTo(PlaybackEpisodeNumber other) {
    var order = (season ?? 1).compareTo(other.season ?? 1);
    return order != 0 ? order : number.compareTo(other.number);
  }

  static final _extras = RegExp(
    r'(?<![A-Za-z0-9])(?:BATCH|COMPLETE|SP|OVA|OAD|(?:NC)?(?:OP|ED)|PV|CM|'
    r'TRAILER|TEASER|PREVIEW|SAMPLE)(?:\d+)?(?![A-Za-z0-9])|'
    r'合集|全集|特别篇|特別篇|特典|预告|預告|予告|'
    r'\d{1,4}(?:\.\d+)?(?:v\d+)?[-+~～至]\s*\d{1,4}',
    caseSensitive: false,
  );
  static final _seasonOnly = RegExp(
    r'(?<![A-Za-z0-9])(?:S\d{1,2}(?!\d)|'
    r'Season[ ._-]*\d{1,2}(?!\d)|'
    r'\d{1,2}(?:st|nd|rd|th)[ ._-]+Season\b)|'
    r'第\s*[0-9〇零一二三四五六七八九十百两兩]+\s*[季期]',
    caseSensitive: false,
  );
  static final _seasonEpisodes = [
    RegExp(
      r'(?<![A-Za-z0-9])S(\d{1,2})[ ._-]*E'
      r'(\d{1,4}(?:\.\d+)?)(?:v\d+)?(?![\dA-Za-z])',
      caseSensitive: false,
    ),
    RegExp(
      r'(?<![A-Za-z0-9])(\d{1,2})x'
      r'(\d{1,4}(?:\.\d+)?)(?:v\d+)?(?![\dA-Za-z])',
      caseSensitive: false,
    ),
  ];
  static final _fractionalSpecial = RegExp(
    r'(?<![A-Za-z0-9])SP[ ._-]*(\d{1,4}\.\d+)(?:v\d+)?'
    r'(?![\dA-Za-z.])',
    caseSensitive: false,
  );
  static final _episodes = [
    RegExp(r'第\s*(\d{1,4}(?:\.\d+)?)(?:v\d+)?\s*[话話集]', caseSensitive: false),
    RegExp(
      r'(?<![A-Za-z0-9])(?:Episode|EP?)[ ._-]*'
      r'(\d{1,4}(?:\.\d+)?)(?:v\d+)?(?![\dA-Za-z])',
      caseSensitive: false,
    ),
    RegExp(
      r'\s[-—]\s*(\d{1,4}(?:\.\d+)?)(?:v\d+)?'
      r'(?=$|[\s\[【(])',
      caseSensitive: false,
    ),
    _fractionalSpecial,
  ];
  static final _bracketNumber = RegExp(
    r'[\[【]\s*(\d{1,4}(?:\.\d+)?)(?:v\d+)?\s*[\]】]',
    caseSensitive: false,
  );
  static final _trailingNumber = RegExp(
    r'(?:^|[\s_.-])(\d{1,4}(?:\.\d+)?)(?:v\d+)?$',
    caseSensitive: false,
  );

  static bool _metadata(double number) =>
      (number >= 1900 && number <= 2099) ||
      {264, 265, 360, 480, 576, 720, 1080, 1440, 2160, 4320}.contains(number);

  /// Parse a basename without its file extension, excluding release metadata.
  static PlaybackEpisodeNumber? parse(String name) {
    if (_extras.hasMatch(name.replaceAll(_fractionalSpecial, ' '))) return null;
    var numbers = <double>{};
    var seasons = <int>{};
    PlaybackEpisodeNumber? result;
    for (var pattern in _seasonEpisodes) {
      for (var match in pattern.allMatches(name)) {
        var season = int.parse(match[1]!);
        var number = double.parse(match[2]!);
        seasons.add(season);
        numbers.add(number);
        result ??= PlaybackEpisodeNumber(
          number: number,
          season: season,
          start: match.start,
        );
      }
    }
    for (var pattern in _episodes) {
      for (var match in pattern.allMatches(name)) {
        var number = double.parse(match[1]!);
        numbers.add(number);
        result ??= PlaybackEpisodeNumber(number: number, start: match.start);
      }
    }
    for (var match in _bracketNumber.allMatches(name)) {
      var number = double.parse(match[1]!);
      if (_metadata(number)) continue;
      numbers.add(number);
      result ??= PlaybackEpisodeNumber(number: number, start: match.start);
    }
    if (numbers.length > 1 || seasons.length > 1) return null;
    if (result != null) return result;
    if (_seasonOnly.hasMatch(name)) return null;
    var trailing = _trailingNumber.firstMatch(name);
    if (trailing == null) return null;
    var number = double.parse(trailing[1]!);
    return _metadata(number)
        ? null
        : PlaybackEpisodeNumber(number: number, start: trailing.start);
  }
}
