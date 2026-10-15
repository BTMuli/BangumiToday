// Project imports:
import '../../domain/repositories/episode_mark_gateway.dart';
import '../../models/playback/playback_episode_link.dart';
import '../../models/playback/playback_item.dart';
import 'playback_episode_files.dart';

/// Resume an unfinished chapter, or continue after a completed history entry.
/// Account chapter states take precedence over the aggregate episode count.
PlaybackItem? selectSubjectPlaybackItem({
  required int subject,
  required PlaybackItem? previous,
  required List<PlaybackItem> files,
  required List<PlaybackEpisodeLink> links,
  required List<EpisodeMarkEpisode> chapters,
  required int watchedEpisodes,
}) {
  var available = {
    for (var file in files)
      if (file.subject == subject) file.key: file,
  };
  var matched = {
    for (var link in links)
      if (link.subject == subject && !link.excluded) link.key: link,
  };
  var ordered = List<EpisodeMarkEpisode>.of(chapters)
    ..sort((a, b) {
      var type = a.type.compareTo(b.type);
      return type != 0 ? type : a.sort.compareTo(b.sort);
    });
  var byId = {for (var chapter in ordered) chapter.id: chapter};
  bool watched(EpisodeMarkEpisode chapter) {
    if (chapter.done != null) return chapter.done!;
    var number = chapter.withinSubject;
    if (number == null || !number.isFinite || number <= 0) {
      number = chapter.sort;
    }
    return chapter.type == 0 && number <= watchedEpisodes;
  }

  var previousChapter = byId[matched[previous?.key]?.episode];
  var canResume = previous != null && available.containsKey(previous.key);
  if (canResume &&
      !previous.completed &&
      (previousChapter == null || !watched(previousChapter))) {
    return previous;
  }
  if (canResume && previousChapter != null) {
    // Reuse EOF's chapter ordering, including alternate versions and recaps.
    bool unwatchedFile(PlaybackItem file) {
      var chapter = byId[matched[file.key]?.episode];
      return chapter != null && !watched(chapter);
    }

    var remaining = [
      for (var file in available.values)
        if (file.key == previous.key || unwatchedFile(file)) file,
    ];
    var next = nextPlaybackEpisodeIndex(
      items: remaining,
      currentIndex: remaining.indexWhere((file) => file.key == previous.key),
      episodes: ordered,
      manualLinks: matched,
    );
    return next == null ? null : remaining[next];
  }
  for (var chapter in ordered) {
    if (!chapter.sort.isFinite ||
        watched(chapter) ||
        (watchedEpisodes > 0 && chapter.type != 0)) {
      continue;
    }
    for (var file in available.values) {
      if (matched[file.key]?.episode == chapter.id) return file;
    }
  }
  return null;
}
