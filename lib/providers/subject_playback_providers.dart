// Dart imports:
import 'dart:async';

// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../core/errors/playback_unavailable.dart';
import '../core/utils/playback_episode_files.dart';
import '../data/repositories/episode_mark_gateway_impl.dart';
import '../models/bangumi/bangumi_model.dart';
import '../models/playback/playback_episode_link.dart';
import '../models/playback/playback_item.dart';
import '../store/bt_download_store.dart';
import '../store/playback_store.dart';
import 'bangumi_providers.dart';
import 'bmf_providers.dart';
import 'playback_episode_link_providers.dart';

final subjectFileEpisodesProvider = FutureProvider.autoDispose
    .family<List<BangumiEpisode>, int>((ref, subject) async {
      var repository = ref.watch(bangumiRepositoryProvider);
      var episodes = <BangumiEpisode>[];
      var ids = <int>{};
      int? total;
      while (true) {
        var response = await repository.getEpisodeList(
          subject,
          limit: 100,
          offset: episodes.length,
        );
        if (!ref.mounted) return const [];
        var page = response.data;
        if (response.code != 0 || page == null) {
          throw StateError('获取章节失败：${response.message}');
        }
        if (page.offset != episodes.length ||
            page.total < episodes.length ||
            (total != null && total != page.total)) {
          throw StateError('章节分页已变化，请重试');
        }
        total = page.total;
        for (var episode in page.data) {
          if (!ids.add(episode.id)) throw StateError('章节分页重复，请重试');
          episodes.add(episode);
        }
        if (episodes.length == total) return episodes;
        if (page.data.isEmpty || episodes.length > total) {
          throw StateError('章节列表未完整返回，请重试');
        }
      }
    });

/// Scan once per subject; rescan on configuration or download-state changes.
final subjectPlaybackFilesProvider = FutureProvider.autoDispose
    .family<List<PlaybackItem>, int>((ref, subject) async {
      var repository = ref.watch(bmfRepositoryProvider);
      var subscription = repository.changes.listen((change) {
        if (ref.mounted && change.subject == subject) ref.invalidateSelf();
      });
      ref.onDispose(() => unawaited(subscription.cancel()));
      var manual = ref.watch(subjectEpisodeLinksProvider(subject));
      var library = ref.watch(
        playbackStoreProvider.select((store) => store.library),
      );
      var model = await repository.read(subject);
      if (!ref.mounted) return const [];
      var directory = model?.download;
      if (directory != null && directory.isNotEmpty) {
        var root = PlaybackItem.pathKey(directory);
        // Progress ticks do not change this signature or repeat scans.
        ref.watch(
          btDownloadStoreProvider.select(
            (store) => [
              for (var task in store.tasks)
                if (PlaybackItem.pathKey(task.savePath) == root)
                  '${task.id}:${task.state}',
            ].join('|'),
          ),
        );
      }
      var files = directory == null || directory.isEmpty
          ? <PlaybackItem>[]
          : await library.discover(directory, subject: subject);
      var keys = files.map((file) => file.key).toSet();
      for (var link in manual) {
        if (!ref.mounted) return const [];
        if (!keys.add(link.key)) continue;
        try {
          await library.ensureReady(link.filePath);
          files.add(
            PlaybackItem(
              filePath: link.filePath,
              title: link.filePath,
              subject: subject,
            ),
          );
        } on PlaybackUnavailable {
          // Missing files and incomplete downloads cannot be offered for play.
        }
      }
      return files;
    });

/// Inferred associations are live projections, not durable per-episode writes.
final subjectEpisodeFilesProvider = FutureProvider.autoDispose
    .family<List<PlaybackEpisodeLink>, int>((ref, subject) async {
      var manual = ref.watch(playbackEpisodeLinkSnapshotProvider);
      var fileFuture = ref.watch(subjectPlaybackFilesProvider(subject).future);
      var chapterFuture = ref.watch(
        subjectFileEpisodesProvider(subject).future,
      );
      var (files, chapters) = await (fileFuture, chapterFuture).wait;
      return resolvePlaybackEpisodeFiles(
        subject: subject,
        files: files
            .where((file) => file.subject == subject)
            .map((file) => file.filePath),
        episodes: chapters.map(episodeMarkChapter),
        manualLinks: manual.value ?? const {},
      ).values.toList();
    });
