// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../database/app/playback_episode_links.dart';
import '../domain/repositories/playback_episode_links.dart';
import '../models/playback/playback_episode_link.dart';

final playbackEpisodeLinksProvider = Provider<PlaybackEpisodeLinks>(
  (ref) => PlaybackEpisodeLinksStorage(),
);

final playbackEpisodeLinkSnapshotProvider =
    StreamProvider<Map<String, PlaybackEpisodeLink>>((ref) {
      return ref.watch(playbackEpisodeLinksProvider).watchAll();
    });

final subjectEpisodeLinksProvider = Provider.autoDispose
    .family<List<PlaybackEpisodeLink>, int>((ref, subject) {
      var links = ref.watch(playbackEpisodeLinkSnapshotProvider).value;
      return [
        for (var link in links?.values ?? const <PlaybackEpisodeLink>[])
          if (link.subject == subject) link,
      ];
    });
