// Project imports:
import '../../domain/repositories/episode_mark_gateway.dart';
import '../../models/playback/playback_episode_link.dart';
import '../../models/playback/playback_item.dart';
import 'playback_episode_number.dart';

/// A local video matched to an unwatched Bangumi chapter.
class UnwatchedLocalEpisode {
  const UnwatchedLocalEpisode({
    required this.episodeId,
    required this.sort,
    required this.label,
    required this.fileKey,
    required this.filePath,
  });

  final int episodeId;
  final double sort;
  final String label;
  final String fileKey;
  final String filePath;
}

bool isSubjectEpisodeWatched(
  EpisodeMarkEpisode chapter, {
  required int watchedEpisodes,
  PlaybackItem? local,
}) {
  if (chapter.done != null) return chapter.done!;
  if (local?.completed == true) return true;
  var number = chapter.withinSubject;
  if (number == null || !number.isFinite || number <= 0) {
    number = chapter.sort;
  }
  return chapter.type == 0 && number <= watchedEpisodes;
}

String subjectEpisodeNumberLabel(EpisodeMarkEpisode chapter) {
  var number = chapter.withinSubject;
  if (number == null || !number.isFinite || number < 0) {
    number = chapter.sort;
  }
  return PlaybackEpisodeNumber(number: number, start: 0).label;
}

/// Matched local files whose chapters are still unwatched, ordered by sort.
List<UnwatchedLocalEpisode> selectUnwatchedLocalEpisodes({
  required int subject,
  required List<PlaybackItem> files,
  required List<PlaybackEpisodeLink> links,
  required List<EpisodeMarkEpisode> chapters,
  required int watchedEpisodes,
  Map<String, PlaybackItem> localByPath = const {},
}) {
  var available = {
    for (var file in files)
      if (file.subject == subject) file.key: file,
  };
  var matched = {
    for (var link in links)
      if (link.subject == subject && !link.excluded && link.episode != null)
        link.episode!: link,
  };
  var ordered = List<EpisodeMarkEpisode>.of(chapters)
    ..sort((a, b) {
      var type = a.type.compareTo(b.type);
      return type != 0 ? type : a.sort.compareTo(b.sort);
    });
  var result = <UnwatchedLocalEpisode>[];
  var seen = <int>{};
  for (var chapter in ordered) {
    if (!chapter.sort.isFinite || seen.contains(chapter.id)) continue;
    var link = matched[chapter.id];
    if (link == null || !available.containsKey(link.key)) continue;
    var local = localByPath[link.key];
    if (isSubjectEpisodeWatched(
      chapter,
      watchedEpisodes: watchedEpisodes,
      local: local,
    )) {
      continue;
    }
    seen.add(chapter.id);
    result.add(
      UnwatchedLocalEpisode(
        episodeId: chapter.id,
        sort: chapter.sort,
        label: subjectEpisodeNumberLabel(chapter),
        fileKey: link.key,
        filePath: available[link.key]!.filePath,
      ),
    );
  }
  return result;
}

/// Caption text for the unwatched count trigger; empty when nothing to show.
String formatUnwatchedEpisodeSummary(List<UnwatchedLocalEpisode> episodes) {
  if (episodes.isEmpty) return '';
  return '未看 ${episodes.length}';
}
