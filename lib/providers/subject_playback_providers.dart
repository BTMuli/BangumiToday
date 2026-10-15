// Dart imports:
import 'dart:async';

// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../core/utils/playback_episode_files.dart';
import '../core/utils/subject_playback_selection.dart';
import '../data/repositories/episode_mark_gateway_impl.dart';
import '../data/repositories/playback_episodes.dart';
import '../models/bangumi/bangumi_model.dart';
import '../models/playback/playback_episode_link.dart';
import '../models/playback/playback_item.dart';
import 'bangumi_providers.dart';
import 'episode_mark_providers.dart';
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

/// Read already observed progress without issuing another account request.
final subjectEpisodeProgressProvider = Provider.autoDispose
    .family<Map<int, bool>, int>((ref, subject) {
      ref.watch(episodeMarkProvider);
      return ref
          .read(episodeMarkProvider.notifier)
          .service
          .knownProgress(subject);
    });

/// Resume unfinished history; completed chapters advance to a matched file.
final subjectContinuePlaybackItemProvider = FutureProvider.autoDispose
    .family<PlaybackItem?, ({int subject, int watchedEpisodes})>((
      ref,
      request,
    ) async {
      var subject = request.subject;
      var files = await ref.watch(subjectPlaybackFilesProvider(subject).future);
      if (!ref.mounted || files.isEmpty) return null;
      var progress = ref.watch(subjectEpisodeProgressProvider(subject));
      var historyFuture = ref.watch(
        subjectPlaybackHistoryProvider(subject).future,
      );
      var linksFuture = ref.watch(subjectEpisodeFilesProvider(subject).future);
      var chaptersFuture = ref.watch(
        subjectFileEpisodesProvider(subject).future,
      );
      var (previous, links, chapters) = await (
        historyFuture,
        linksFuture,
        chaptersFuture,
      ).wait;
      if (!ref.mounted) return null;
      return selectSubjectPlaybackItem(
        subject: subject,
        previous: previous,
        files: files,
        links: links,
        chapters: [
          for (var episode in chapters)
            if (progress[episode.id] case var done?)
              episodeMarkChapter(episode).withDone(done)
            else
              episodeMarkChapter(episode),
        ],
        watchedEpisodes: request.watchedEpisodes,
      );
    });
