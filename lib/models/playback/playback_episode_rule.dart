/// A subject-scoped filename format. The first capture is the release number;
/// its offset maps to the selected chapter type's broadcast sort.
class PlaybackEpisodeRule {
  PlaybackEpisodeRule({
    required this.id,
    required this.subject,
    required this.pattern,
    required this.offset,
    required this.type,
    required this.exampleFile,
  }) : expression = RegExp(pattern, caseSensitive: false);

  final String id;
  final int subject;
  final String pattern;
  final double offset;
  final int type;
  final String exampleFile;
  final RegExp expression;

  static String filename(String value) => value
      .trim()
      .replaceAll(RegExp(r'^"|"$'), '')
      .split(RegExp(r'[/\\]'))
      .last
      .replaceFirst(
        RegExp(
          r'\.(?:mp4|mkv|avi|mov|webm|m4v|ts|m2ts|wmv|flv|mpg|mpeg|ogv)$',
          caseSensitive: false,
        ),
        '',
      );

  bool appliesTo(String file) => expression.hasMatch(filename(file));

  double? numberFor(String file) {
    var matches = expression.allMatches(filename(file)).toList();
    if (matches.length != 1 || matches.single.groupCount < 1) return null;
    var number = double.tryParse(matches.single[1] ?? '');
    if (number == null) return null;
    var result = number + offset;
    return result.isFinite && result > 0 ? result : null;
  }

  factory PlaybackEpisodeRule.fromJson(Map<String, dynamic> value) =>
      PlaybackEpisodeRule(
        id: value['id'] as String,
        subject: value['subject'] as int,
        pattern: value['pattern'] as String,
        offset: (value['offset'] as num).toDouble(),
        type: value['type'] as int,
        exampleFile: value['exampleFile'] as String,
      );

  Map<String, Object> toJson() => {
    'id': id,
    'subject': subject,
    'pattern': pattern,
    'offset': offset,
    'type': type,
    'exampleFile': exampleFile,
  };
}
