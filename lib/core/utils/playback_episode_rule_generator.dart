// Project imports:
import '../../models/playback/playback_episode_rule.dart';
import 'episode_num_extractor.dart';

class EpisodeRuleNumber {
  const EpisodeRuleNumber(this.start, this.end, this.text);

  final int start;
  final int end;
  final String text;
  double get number => double.parse(text);
}

/// Keep all plausible positions so duplicate title/episode numbers require
/// an explicit choice instead of silently replacing the wrong number.
List<EpisodeRuleNumber> episodeRuleNumbers(String file) => [
  for (var match in RegExp(
    r'(?<![\d.])\d{1,4}(?:\.\d+)?(?![\d.])',
  ).allMatches(PlaybackEpisodeRule.filename(file)))
    if (!{
          264,
          265,
          360,
          480,
          576,
          720,
          1080,
          1440,
          2160,
          4320,
        }.contains(double.parse(match[0]!)) &&
        !(double.parse(match[0]!) >= 1900 && double.parse(match[0]!) <= 2099))
      EpisodeRuleNumber(match.start, match.end, match[0]!),
];

EpisodeRuleNumber? suggestEpisodeRuleNumber(String file, double target) {
  var numbers = episodeRuleNumbers(file);
  var matching = numbers.where((number) => number.number == target).toList();
  if (matching.length == 1) return matching.single;
  if (matching.length > 1) return null;
  var evidence = extractEpisodeNumber(file);
  if (evidence.kind == EpisodeNumberKind.single) {
    matching = numbers
        .where((number) => number.number == evidence.number)
        .toList();
    if (matching.length == 1) return matching.single;
  }
  return numbers.singleOrNull;
}

String generateEpisodeRulePattern(String file, EpisodeRuleNumber number) {
  var name = PlaybackEpisodeRule.filename(file);
  if (!episodeRuleNumbers(file).any(
    (candidate) =>
        candidate.start == number.start && candidate.end == number.end,
  )) {
    throw ArgumentError('请重新选择文件名中的集数');
  }
  String escape(String value) =>
      value.split(RegExp(r'(\s+)')).map(RegExp.escape).join(r'\s+');
  var prefix = escape(name.substring(0, number.start));
  var suffix = name.substring(number.end);
  // Release revisions may vary between episodes.
  suffix = suffix.replaceFirst(RegExp(r'^v\d+', caseSensitive: false), '');
  var metadata = suffix.indexOf(RegExp(r'[\[【(]'));
  var tail = metadata < 0
      ? escape(suffix)
      : '${escape(suffix.substring(0, metadata + 1))}.*';
  return '^$prefix'
      r'(\d{1,4}(?:\.\d+)?)(?:v\d+)?'
      '$tail\$';
}
