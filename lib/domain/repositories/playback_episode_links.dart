// Project imports:
import '../../models/playback/playback_episode_link.dart';

abstract interface class PlaybackEpisodeLinks {
  Future<Map<String, PlaybackEpisodeLink>> readAll();
  Stream<Map<String, PlaybackEpisodeLink>> watchAll();
  Future<void> write(PlaybackEpisodeLink link);

  /// Remove only this association, preserving a newer reassignment.
  Future<void> remove(PlaybackEpisodeLink link);
}
