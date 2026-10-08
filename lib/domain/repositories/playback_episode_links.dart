// Project imports:
import '../../models/playback/playback_episode_link.dart';
import '../../models/playback/playback_episode_rule.dart';

abstract interface class PlaybackEpisodeLinks {
  Future<Map<String, PlaybackEpisodeLink>> readAll();
  Stream<Map<String, PlaybackEpisodeLink>> watchAll();
  Future<void> write(PlaybackEpisodeLink link);

  /// Remove only this association, preserving a newer reassignment.
  Future<void> remove(PlaybackEpisodeLink link);

  Future<List<PlaybackEpisodeRule>> readRules();
  Stream<List<PlaybackEpisodeRule>> watchRules();
  Future<void> writeRule(PlaybackEpisodeRule rule);
  Future<void> removeRule(PlaybackEpisodeRule rule);
}
