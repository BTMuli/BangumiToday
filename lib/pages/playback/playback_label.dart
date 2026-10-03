import 'package:path/path.dart' as path;

/// Display labels only; the original filename remains available in tooltips.
class PlaybackLabel {
  const PlaybackLabel({
    required this.title,
    required this.details,
    this.episode,
  });

  final String title;
  final String details;
  final String? episode;

  factory PlaybackLabel.fromName(String name) {
    var base = path.basenameWithoutExtension(name);
    var extension = path.extension(name).replaceFirst('.', '').toUpperCase();
    var resolution = RegExp(
      r'(?<!\d)(2160|1080|720|480)[pi](?![a-z0-9])',
      caseSensitive: false,
    ).firstMatch(base)?.group(0)?.toUpperCase();
    var seasonEpisode = RegExp(
      r'S(\d{1,2})[ ._-]*E(\d{1,3})(?!\d)',
      caseSensitive: false,
    );
    var episodePatterns = [
      RegExp(r'第\s*(\d{1,3}(?:\.\d+)?)\s*[话話集]'),
      RegExp(
        r'(?:^|[\s_.-])(?:Episode|EP?)\s*(\d{1,3}(?:\.\d+)?)(?!\d)',
        caseSensitive: false,
      ),
      RegExp(r'\s-\s*(\d{1,3}(?:\.\d+)?)(?=\s|\[|【|$)'),
      RegExp(r'\[(\d{1,2}(?:\.\d+)?)\]'),
    ];
    String? episode;
    var seasonMatch = seasonEpisode.firstMatch(base);
    if (seasonMatch != null) {
      episode =
          '第 ${int.parse(seasonMatch[1]!)} 季 · '
          '第 ${int.parse(seasonMatch[2]!)} 集';
    } else {
      for (var pattern in episodePatterns) {
        var match = pattern.firstMatch(base);
        if (match == null) continue;
        var number = match[1]!;
        episode = '第 ${int.tryParse(number) ?? number} 集';
        break;
      }
    }
    var title = base
        .replaceAll(RegExp(r'\[[^\]]*\]|【[^】]*】'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    var episodeMatch = seasonEpisode.firstMatch(title);
    episodeMatch ??= episodePatterns
        .map((pattern) => pattern.firstMatch(title))
        .whereType<RegExpMatch>()
        .firstOrNull;
    if (episodeMatch != null) title = title.substring(0, episodeMatch.start);
    title = title.replaceAll(RegExp(r'[\s_.-]+$'), '').trim();
    if (title.isEmpty) title = base;
    return PlaybackLabel(
      title: title,
      episode: episode,
      details: [?resolution, if (extension.isNotEmpty) extension].join(' · '),
    );
  }
}
