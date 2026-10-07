// Package imports:
import 'package:path/path.dart' as path;

// Project imports:
import '../../core/utils/playback_episode_number.dart';

/// Display labels only; the original filename remains available in tooltips.
class PlaybackLabel {
  const PlaybackLabel({
    required this.title,
    required this.details,
    this.episode,
    this.episodeNumber,
  });

  final String title;
  final String details;
  final String? episode;
  final String? episodeNumber;

  factory PlaybackLabel.fromName(String name) {
    var base = path.basenameWithoutExtension(name);
    var extension = path.extension(name).replaceFirst('.', '').toUpperCase();
    var resolution = RegExp(
      r'(?<!\d)(2160|1080|720|480)[pi](?![a-z0-9])',
      caseSensitive: false,
    ).firstMatch(base)?.group(0)?.toUpperCase();
    var parsed = PlaybackEpisodeNumber.parse(base);
    var episodeNumber = parsed?.label;
    var episode = parsed == null
        ? null
        : [
            if (parsed.season != null) '第 ${parsed.season} 季',
            '第 ${parsed.label} 集',
          ].join(' · ');
    var title = base
        .replaceAll(RegExp(r'\[[^\]]*\]|【[^】]*】'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    var episodeMatch = PlaybackEpisodeNumber.parse(title);
    if (parsed != null &&
        episodeMatch != null &&
        episodeMatch.number == parsed.number &&
        episodeMatch.season == parsed.season) {
      title = title.substring(0, episodeMatch.start);
    }
    title = title.replaceAll(RegExp(r'[\s_.-]+$'), '').trim();
    if (title.isEmpty) title = base;
    return PlaybackLabel(
      title: title,
      episode: episode,
      episodeNumber: episodeNumber,
      details: [?resolution, if (extension.isNotEmpty) extension].join(' · '),
    );
  }
}
