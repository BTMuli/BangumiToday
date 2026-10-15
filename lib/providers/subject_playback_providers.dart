// Dart imports:
import 'dart:async';

// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;

// Project imports:
import '../core/utils/playback_episode_files.dart';
import '../data/repositories/episode_mark_gateway_impl.dart';
import '../data/repositories/playback_episodes.dart';
import '../models/bangumi/bangumi_enum.dart';
import '../models/bangumi/bangumi_model.dart';
import '../models/playback/playback_episode_link.dart';
import '../models/playback/playback_item.dart';
import 'bangumi_providers.dart';
import 'playback_episode_link_providers.dart';
import 'subject_local_file_providers.dart';

export 'subject_local_file_providers.dart'
    show subjectLocalFilesProvider, subjectPlaybackHistoryProvider;

final subjectFileEpisodesProvider = FutureProvider.autoDispose
    .family<List<BangumiEpisode>, int>((ref, subject) async {
      var repository = ref.watch(bangumiRepositoryProvider);
      return loadPlaybackEpisodes(
        repository,
        subject,
        isCurrent: () => ref.mounted,
      );
    });

/// Share the file list's scan and download metadata instead of scanning twice.
final subjectPlaybackFilesProvider = FutureProvider.autoDispose
    .family<List<PlaybackItem>, int>((ref, subject) async {
      return (await ref.watch(
        subjectLocalFilesProvider(subject).future,
      )).playable;
    });

/// Inferred associations are live projections, not durable per-episode writes.
final subjectEpisodeFilesProvider = FutureProvider.autoDispose
    .family<List<PlaybackEpisodeLink>, int>((ref, subject) async {
      var files = await ref.watch(subjectPlaybackFilesProvider(subject).future);
      if (!ref.mounted || files.isEmpty) return const [];
      var manual = ref.watch(playbackEpisodeLinkSnapshotProvider);
      var rules = ref.watch(playbackEpisodeRuleSnapshotProvider);
      var ruleFuture = rules.hasValue
          ? Future.value(rules.value!)
          : ref.watch(playbackEpisodeRuleSnapshotProvider.future);
      var chapterFuture = ref.watch(
        subjectFileEpisodesProvider(subject).future,
      );
      var (chapters, savedRules) = await (chapterFuture, ruleFuture).wait;
      return resolvePlaybackEpisodeFiles(
        subject: subject,
        files: files
            .where((file) => file.subject == subject)
            .map((file) => file.filePath),
        episodes: chapters.map(episodeMarkChapter),
        manualLinks: manual.value ?? const {},
        rules: savedRules,
      ).values.toList();
    });

/// Follow chapter order, skipping watched main episodes when progress is known.
final subjectNextPlaybackItemProvider = FutureProvider.autoDispose
    .family<PlaybackItem?, ({int subject, int watchedEpisodes})>((
      ref,
      request,
    ) async {
      var subject = request.subject;
      var files = await ref.watch(subjectEpisodeFilesProvider(subject).future);
      if (!ref.mounted || files.isEmpty) return null;
      var chapters =
          List<BangumiEpisode>.of(
            await ref.watch(subjectFileEpisodesProvider(subject).future),
          )..sort((a, b) {
            var type = a.type.value.compareTo(b.type.value);
            return type != 0 ? type : a.sort.compareTo(b.sort);
          });
      for (var chapter in chapters) {
        if (request.watchedEpisodes > 0 &&
            (chapter.type != BangumiEpType.main ||
                chapter.sort <= request.watchedEpisodes)) {
          continue;
        }
        var file = files
            .where((file) => file.episode == chapter.id)
            .firstOrNull;
        if (file == null) continue;
        return PlaybackItem(
          filePath: file.filePath,
          title: path.basename(file.filePath),
          subject: subject,
        );
      }
      return null;
    });
