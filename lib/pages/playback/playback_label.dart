// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;

// Project imports:
import '../../core/utils/episode_num_extractor.dart';
import '../../core/utils/playback_episode_number.dart';
import '../../core/utils/playback_paths.dart';
import '../../models/bangumi/bangumi_model_episode.dart';
import '../../models/playback/playback_episode_link.dart';
import '../../models/playback/playback_episode_rule.dart';
import '../../models/playback/playback_item.dart';
import '../../providers/playback_episode_link_providers.dart';
import '../../providers/subject_playback_providers.dart';
import '../../store/playback_store.dart';

final playbackLabelProvider = Provider.autoDispose
    .family<PlaybackLabel, PlaybackItem>((ref, item) {
      var subject = item.subject;
      var rules = subject == null
          ? const <PlaybackEpisodeRule>[]
          : ref.watch(subjectEpisodeRulesProvider(subject));
      var manual = ref
          .watch(playbackEpisodeLinkSnapshotProvider)
          .value?[item.key];
      var chapters =
          manual != null && manual.subject == subject && !manual.excluded
          ? ref.watch(subjectFileEpisodesProvider(manual.subject)).value
          : null;
      return PlaybackLabel.fromItem(
        item,
        rules: rules,
        manualLink: manual,
        chapters: chapters ?? const [],
      );
    });

/// Keep presentation order separate from the session's stable file indices.
/// Selection, navigation and scrolling all use this same projection.
final playbackPlaylistProvider = Provider.autoDispose<PlaybackPlaylist>((ref) {
  var items = ref.watch(
    playbackStoreProvider.select((store) => store.playlist),
  );
  return PlaybackPlaylist.fromItems(items, [
    for (var item in items) ref.watch(playbackLabelProvider(item)),
  ]);
});

class PlaybackPlaylist {
  PlaybackPlaylist.fromItems(
    List<PlaybackItem> items,
    List<PlaybackLabel> labels,
  ) : indices = List.generate(items.length, (index) => index) {
    indices.sort((a, b) {
      var left = labels[a].number;
      var right = labels[b].number;
      if (left != null && right != null) {
        var order = left.compareTo(right);
        if (order != 0) return order;
      } else if (left != null || right != null) {
        return left != null ? -1 : 1;
      }
      var order = PlaybackPaths.naturalCompare(items[a].title, items[b].title);
      return order != 0
          ? order
          : PlaybackPaths.naturalCompare(items[a].filePath, items[b].filePath);
    });
  }

  final List<int> indices;

  int positionOf(int index) => indices.indexOf(index);
}

/// Display labels only; the original filename remains available in tooltips.
class PlaybackLabel {
  const PlaybackLabel({
    required this.title,
    required this.details,
    this.episode,
    this.number,
  });

  final String title;
  final String details;
  final String? episode;
  final PlaybackEpisodeNumber? number;
  String? get episodeNumber => number?.label;

  factory PlaybackLabel.fromItem(
    PlaybackItem item, {
    Iterable<PlaybackEpisodeRule> rules = const [],
    PlaybackEpisodeLink? manualLink,
    Iterable<BangumiEpisode> chapters = const [],
  }) {
    var label = PlaybackLabel.fromName(item.title, filePath: item.filePath);
    if (manualLink != null && manualLink.key == item.key) {
      var chapter = manualLink.subject == item.subject && !manualLink.excluded
          ? chapters
                .where((chapter) => chapter.id == manualLink.episode)
                .singleOrNull
          : null;
      var number = chapter?.sort;
      return label._withNumber(
        number != null && number.isFinite && number >= 0 ? number : null,
      );
    }
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
    return label._withNumber(number);
  }

  PlaybackLabel _withNumber(double? value) {
    var number = value == null
        ? null
        : PlaybackEpisodeNumber(number: value, start: 0);
    return PlaybackLabel(
      title: title,
      details: details,
      episode: number == null ? null : '第 ${number.label} 集',
      number: number,
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
      number: parsed,
      details: [?resolution, if (extension.isNotEmpty) extension].join(' · '),
    );
  }
}
