// Dart imports:
import 'dart:async';
import 'dart:io';

// Package imports:
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;

// Project imports:
import '../core/services/subject_file_monitor.dart';
import '../data/repositories/subject_local_files.dart';
import '../database/app/app_playback.dart';
import '../models/playback/playback_item.dart';
import '../store/bt_dir_download_state.dart';
import '../store/bt_download_store.dart';
import '../store/nav_store.dart';
import 'bmf_providers.dart';
import 'playback_episode_link_providers.dart';

final subjectPlaybackHistoryProvider = StreamProvider.autoDispose
    .family<PlaybackItem?, int>((ref, subject) {
      return BtsAppPlayback().watchLatestForSubject(subject);
    });

final subjectFilesActiveProvider = Provider.autoDispose.family<bool, int>((
  ref,
  subject,
) {
  return ref.watch(
    navStoreProvider.select(
      (nav) => nav.pageKeyForIndex(nav.curIndex) == 'subjectDetail_$subject',
    ),
  );
});

final subjectLocalFilesProvider = AsyncNotifierProvider.autoDispose
    .family<SubjectLocalFilesNotifier, SubjectLocalFiles, int>(
      SubjectLocalFilesNotifier.new,
    );

class SubjectLocalFilesNotifier extends AsyncNotifier<SubjectLocalFiles> {
  SubjectLocalFilesNotifier(this.subject);

  final int subject;
  SubjectLocalFiles _last = const SubjectLocalFiles();
  int _generation = 0;

  @override
  Future<SubjectLocalFiles> build() async {
    var generation = ++_generation;
    var buildRef = ref;
    if (!ref.watch(subjectFilesActiveProvider(subject))) return _last;
    var repository = ref.watch(bmfRepositoryProvider);
    Timer? debounce;
    Timer? poll;
    Timer? retry;
    void schedule() {
      if (!buildRef.mounted || generation != _generation) return;
      debounce?.cancel();
      debounce = Timer(const Duration(milliseconds: 500), ref.invalidateSelf);
    }

    var subscription = repository.changes.listen((change) {
      if (change.subject == subject) schedule();
    });
    ref.onDispose(() {
      debounce?.cancel();
      poll?.cancel();
      retry?.cancel();
      unawaited(subscription.cancel());
    });
    var extraFiles = {
      for (var link in ref.watch(subjectEpisodeLinksProvider(subject)))
        link.filePath,
      ?ref.watch(
        subjectPlaybackHistoryProvider(
          subject,
        ).select((history) => history.value?.filePath),
      ),
    };
    var links = ref.watch(playbackEpisodeLinksProvider);
    var model = await repository.read(subject);
    if (!ref.mounted || generation != _generation) return _last;
    var directory = model?.download;
    if (directory?.isEmpty == true) directory = null;
    var root = directory == null ? null : PlaybackItem.pathKey(directory);
    bool relevant(String savePath) {
      var taskRoot = PlaybackItem.pathKey(savePath);
      return (root != null &&
              (taskRoot == root ||
                  path.isWithin(root, taskRoot) ||
                  path.isWithin(taskRoot, root))) ||
          extraFiles.any(
            (file) => path.isWithin(taskRoot, PlaybackItem.pathKey(file)),
          );
    }

    // Byte/rate ticks do not rebuild the provider or repeat directory scans.
    ref.watch(
      btDownloadStoreProvider.select(
        (store) => [
          for (var task in store.tasks)
            if (relevant(task.savePath))
              '${task.id}:${task.state}:${task.savePath}',
        ].join('|'),
      ),
    );
    var tasks = ref
        .read(btDownloadStoreProvider)
        .tasks
        .where((task) => relevant(task.savePath))
        .toList();
    var downloading = tasks
        .where(
          (task) =>
              !isTaskAvailable(task) &&
              !{'paused', 'stopped', 'error'}.contains(task.state),
        )
        .toList();
    var monitor = SubjectFileMonitor(
      directory: directory,
      files: extraFiles,
      onChange: (event) {
        // Engine writes are checked in batches, not once per disk write.
        if (event is FileSystemModifyEvent &&
            downloading.any((task) {
              var taskRoot = PlaybackItem.pathKey(task.savePath);
              var changed = PlaybackItem.pathKey(event.path);
              return changed == taskRoot || path.isWithin(taskRoot, changed);
            })) {
          return;
        }
        schedule();
      },
      onUnavailable: () {
        if (!buildRef.mounted || generation != _generation) return;
        // Retry unsupported/unavailable watches without a tight refresh loop.
        retry ??= Timer(const Duration(seconds: 30), ref.invalidateSelf);
      },
    );
    ref.onDispose(monitor.dispose);
    await monitor.start();
    if (!ref.mounted || generation != _generation) return _last;
    var downloads = ref.read(btDownloadStoreProvider.notifier);
    try {
      var result = await loadSubjectLocalFiles(
        subject: subject,
        directory: directory,
        extraFiles: extraFiles,
        tasks: tasks,
        taskFiles: (id, offset) => downloads.taskFiles(id, offset: offset),
        links: links,
      );
      if (ref.mounted && generation == _generation) _last = result;
      return result;
    } finally {
      if (ref.mounted && generation == _generation && downloading.isNotEmpty) {
        poll = Timer(const Duration(seconds: 10), ref.invalidateSelf);
      }
    }
  }

  Future<SubjectLocalFiles> refresh() {
    ref.invalidateSelf();
    return future;
  }
}
