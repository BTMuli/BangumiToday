// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;

// Project imports:
import '../../core/utils/episode_num_extractor.dart';
import '../../core/utils/playback_episode_number.dart';
import '../../models/playback/playback_episode_rule.dart';
import '../../models/playback/playback_item.dart';
import '../../providers/playback_episode_link_providers.dart';

final playbackLabelProvider = Provider.autoDispose
    .family<PlaybackLabel, PlaybackItem>((ref, item) {
      var subject = item.subject;
      var rules = subject == null
          ? const <PlaybackEpisodeRule>[]
          : ref.watch(subjectEpisodeRulesProvider(subject));
      return PlaybackLabel.fromItem(item, rules: rules);
    });

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

  factory PlaybackLabel.fromItem(
    PlaybackItem item, {
    Iterable<PlaybackEpisodeRule> rules = const [],
  }) {
    var label = PlaybackLabel.fromName(item.title, filePath: item.filePath);
    var applicable = rules.where(
      (rule) => rule.subject == item.subject && rule.appliesTo(item.filePath),
    );
    if (applicable.isEmpty) return label;
    double? number;
    int? type;
    for (var rule in applicable) {
      var candidate = rule.numberFor(item.filePath);
      // Conflicting or invalid rules must not fall back to filename guessing.
      if (candidate == null ||
          (number != null && (number != candidate || type != rule.type))) {
        number = null;
        break;
      }
      number = candidate;
      type = rule.type;
    }
    var episodeNumber = number == null
        ? null
        : PlaybackEpisodeNumber(number: number, start: 0).label;
    return PlaybackLabel(
      title: label.title,
      details: label.details,
      episode: episodeNumber == null ? null : '第 $episodeNumber 集',
      episodeNumber: episodeNumber,
    );
  }

  factory PlaybackLabel.fromName(String name, {String? filePath}) {
    var base = path.basenameWithoutExtension(name);
    var extension = path.extension(name).replaceFirst('.', '').toUpperCase();
    var resolution = RegExp(
      r'(?<!\d)(2160|1080|720|480)[pi](?![a-z0-9])',
      caseSensitive: false,
    ).firstMatch(base)?.group(0)?.toUpperCase();
    var parsed = isPlaybackExtra(filePath ?? name)
        ? null
        : PlaybackEpisodeNumber.parse(base);
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
