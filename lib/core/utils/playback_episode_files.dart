// Package imports:
import 'package:path/path.dart' as path;

// Project imports:
import '../../domain/repositories/episode_mark_gateway.dart';
import '../../models/playback/playback_episode_link.dart';
import '../../models/playback/playback_item.dart';
import '../services/episode_mark_service.dart';
import 'playback_paths.dart';

/// Apply the player's conservative filename matcher to a whole file list.
/// Explicit corrections take precedence, including blocking stale/foreign links.
Map<String, PlaybackEpisodeLink> resolvePlaybackEpisodeFiles({
  required int subject,
  required Iterable<String> files,
  required Iterable<EpisodeMarkEpisode> episodes,
  required Map<String, PlaybackEpisodeLink> manualLinks,
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
    if (manual != null && manual.subject != subject) continue;
    var chapter = EpisodeMarkService.matchingEpisode(
      item,
      chapters,
      episodeId: manual?.episode,
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
