// Package imports:
import 'package:path/path.dart' as path;

// Project imports:
import '../../domain/repositories/episode_mark_gateway.dart';
import '../../models/playback/playback_episode_link.dart';
import '../../models/playback/playback_episode_rule.dart';
import '../../models/playback/playback_item.dart';
import '../services/episode_mark_service.dart';
import 'playback_episode_number.dart';
import 'playback_paths.dart';

/// Apply the player's conservative filename matcher to a whole file list.
/// Explicit corrections take precedence, including blocking stale/foreign links.
Map<String, PlaybackEpisodeLink> resolvePlaybackEpisodeFiles({
  required int subject,
  required Iterable<String> files,
  required Iterable<EpisodeMarkEpisode> episodes,
  required Map<String, PlaybackEpisodeLink> manualLinks,
  Iterable<PlaybackEpisodeRule> rules = const [],
}) {
  var chapters = episodes.toList();
  var result = <String, PlaybackEpisodeLink>{};
  for (var file in files) {
    if (!PlaybackPaths.isVideo(file)) continue;
    var item = PlaybackItem(
      filePath: file,
      title: path.basename(file),
      subject: subject,
    );
    var manual = manualLinks[item.key];
    if (manual != null && (manual.subject != subject || manual.excluded)) {
      continue;
    }
    var chapter = EpisodeMarkService.matchingEpisode(
      item,
      chapters,
      episodeId: manual?.episode,
      rules: rules,
    );
    if (chapter == null) continue;
    result[item.key] = PlaybackEpisodeLink(
      filePath: file,
      subject: subject,
      episode: chapter.id,
    );
  }
  return Map.unmodifiable(result);
}

/// Advance by chapter, retaining alternate files for explicit selection.
/// Missing chapters, unmatched files and duplicate versions are skipped.
int? nextPlaybackEpisodeIndex({
  required List<PlaybackItem> items,
  required int currentIndex,
  required Iterable<EpisodeMarkEpisode> episodes,
  required Map<String, PlaybackEpisodeLink> manualLinks,
  Iterable<PlaybackEpisodeRule> rules = const [],
}) {
  if (currentIndex < 0 || currentIndex >= items.length) return null;
  var current = items[currentIndex];
  var subject = current.subject;
  if (subject == null) {
    var number = PlaybackEpisodeNumber.fromPath(current.filePath);
    if (number == null) return null;
    PlaybackEpisodeNumber? nextNumber;
    int? nextIndex;
    for (var i = 0; i < items.length; i++) {
      if (items[i].subject != null) continue;
      var candidate = PlaybackEpisodeNumber.fromPath(items[i].filePath);
      if (candidate == null || candidate.compareTo(number) <= 0) continue;
      if (nextNumber == null || candidate.compareTo(nextNumber) < 0) {
        nextNumber = candidate;
        nextIndex = i;
      }
    }
    return nextIndex;
  }
  var chapters = episodes.toList();
  var matched = resolvePlaybackEpisodeFiles(
    subject: subject,
    files: items
        .where((item) => item.subject == subject)
        .map((item) => item.filePath),
    episodes: chapters,
    manualLinks: manualLinks,
    rules: rules,
  );
  var chapterById = {for (var chapter in chapters) chapter.id: chapter};
  var chapter = chapterById[matched[current.key]?.episode];
  if (chapter == null || !chapter.sort.isFinite) return null;
  // Numbered recaps share the broadcast sequence; unrelated specials do not.
  bool broadcast(EpisodeMarkEpisode episode) =>
      episode.type == 0 ||
      (episode.type == 1 && episode.sort != episode.sort.truncateToDouble());
  EpisodeMarkEpisode? nextChapter;
  int? nextIndex;
  for (var i = 0; i < items.length; i++) {
    var candidate = chapterById[matched[items[i].key]?.episode];
    if (candidate == null ||
        (candidate.type != chapter.type &&
            !(broadcast(candidate) && broadcast(chapter))) ||
        !candidate.sort.isFinite ||
        candidate.sort <= chapter.sort) {
      continue;
    }
    if (nextChapter == null || candidate.sort < nextChapter.sort) {
      nextChapter = candidate;
      nextIndex = i;
    }
  }
  return nextIndex;
}
