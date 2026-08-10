// Package imports:
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:bangumi_today/core/services/bt_engine/protocol.dart';
import 'package:bangumi_today/store/bt_dir_download_state.dart';

void main() {
  group('computeDirDownloadState', () {
    BtTaskSnapshot task({
      String id = 'task',
      required String state,
      String savePath = r'D:\Anime',
      String displayName = 'Anime - 01.mkv',
      int totalBytes = 100,
      int verifiedBytes = 0,
      double progress = 0,
    }) {
      return BtTaskSnapshot(
        id: id,
        state: state,
        sourceKind: 'torrentFile',
        savePath: savePath,
        displayName: displayName,
        infoHash: 'abc',
        totalBytes: totalBytes,
        downloadedBytes: 50,
        verifiedBytes: verifiedBytes,
        uploadedBytes: 0,
        shareRatio: 0,
        seedingSeconds: 0,
        seedRatioLimit: 2,
        seedTimeLimitMinutes: 60,
        seedStopReason: null,
        progress: progress,
        downloadRate: 10,
        uploadRate: 0,
        peers: 1,
        seeds: 0,
        isPrivate: false,
        lastError: null,
      );
    }

    BtTaskFileDetail file({
      String filePath = 'Anime - 01.mkv',
      int size = 1000,
      int completedBytes = 100,
      int priority = 4,
    }) {
      return BtTaskFileDetail(
        path: filePath,
        size: size,
        completedBytes: completedBytes,
        priority: priority,
      );
    }

    test('matches tasks by normalized case-insensitive save path', () {
      var state = computeDirDownloadState(
        dir: r'd:\anime\',
        tasks: [task(state: 'downloading', savePath: r'D:\Anime')],
        fileDetailsByTaskId: const {},
        dirFileNames: const ['Anime - 01.mkv'],
      );

      expect(state.activeTaskCount, 1);
      expect(state.hasActiveTasks, isTrue);
      expect(state.stateFor('Anime - 01.mkv')?.isActive, isTrue);
    });

    test('ignores tasks saving to other directories', () {
      var state = computeDirDownloadState(
        dir: r'D:\Anime',
        tasks: [task(state: 'downloading', savePath: r'D:\Other')],
        fileDetailsByTaskId: const {},
      );

      expect(state.activeTaskCount, 0);
      expect(state.hasActiveTasks, isFalse);
      expect(state.byName, isEmpty);
    });

    test('classifies every task state', () {
      var expected = <String, ({bool complete, bool active, String label})>{
        'downloading': (complete: false, active: true, label: '下载中'),
        'queued': (complete: false, active: true, label: '排队中'),
        'metadata': (complete: false, active: true, label: '获取元数据'),
        'checking': (complete: false, active: true, label: '校验中'),
        'paused': (complete: false, active: false, label: '已暂停'),
        'error': (complete: false, active: false, label: '下载失败'),
        'seeding': (complete: true, active: false, label: '已完成'),
        'completed': (complete: true, active: false, label: '已完成'),
      };

      for (var entry in expected.entries) {
        var state = computeDirDownloadState(
          dir: r'D:\Anime',
          tasks: [task(state: entry.key)],
          fileDetailsByTaskId: {
            'task': [file(completedBytes: 500)],
          },
          dirFileNames: const ['Anime - 01.mkv'],
        );
        var fileState = state.stateFor('Anime - 01.mkv');

        expect(fileState?.isComplete, entry.value.complete);
        expect(fileState?.isActive, entry.value.active);
        expect(fileState?.statusLabel, entry.value.label);
        if (!entry.value.complete) {
          expect(fileState?.progress, closeTo(0.5, 0.001));
        } else {
          expect(fileState?.progress, isNull);
        }
      }
    });

    test('treats verified task as available while downloading', () {
      var state = computeDirDownloadState(
        dir: r'D:\Anime',
        tasks: [
          task(state: 'downloading', totalBytes: 100, verifiedBytes: 100),
        ],
        fileDetailsByTaskId: {
          'task': [file()],
        },
        dirFileNames: const ['Anime - 01.mkv'],
      );

      expect(state.stateFor('Anime - 01.mkv')?.isComplete, isTrue);
      expect(state.activeTaskCount, 0);
    });

    test('marks a fully downloaded file complete within an active task', () {
      var state = computeDirDownloadState(
        dir: r'D:\Anime',
        tasks: [task(state: 'downloading')],
        fileDetailsByTaskId: {
          'task': [file(completedBytes: 1000)],
        },
        dirFileNames: const ['Anime - 01.mkv'],
      );

      var fileState = state.stateFor('Anime - 01.mkv');
      expect(fileState?.isComplete, isTrue);
      expect(fileState?.isIncomplete, isFalse);
      expect(state.incompleteFileCount, 0);
    });

    test('ignores skipped files', () {
      var state = computeDirDownloadState(
        dir: r'D:\Anime',
        tasks: [task(state: 'downloading')],
        fileDetailsByTaskId: {
          'task': [file(priority: 0)],
        },
        dirFileNames: const ['Anime - 01.mkv'],
      );

      expect(state.byName, isEmpty);
      expect(state.activeTaskCount, 1);
    });

    test('matches subdirectory files by basename', () {
      var state = computeDirDownloadState(
        dir: r'D:\Anime',
        tasks: [task(state: 'downloading')],
        fileDetailsByTaskId: {
          'task': [file(filePath: 'Season 1/Anime - 01.mkv')],
        },
        dirFileNames: const ['Anime - 01.mkv'],
      );

      expect(state.stateFor('Anime - 01.mkv')?.isActive, isTrue);
      expect(state.incompleteFileCount, 1);
    });

    test('counts only visible files as incomplete', () {
      var state = computeDirDownloadState(
        dir: r'D:\Anime',
        tasks: [task(state: 'downloading')],
        fileDetailsByTaskId: {
          'task': [file(filePath: 'Season 1/Anime - 01.mkv')],
        },
        dirFileNames: const ['Other.mkv'],
      );

      expect(state.incompleteFileCount, 0);
      expect(state.activeTaskCount, 1);
      expect(state.hasActiveTasks, isTrue);
    });

    test('falls back to display name when file details are missing', () {
      var state = computeDirDownloadState(
        dir: r'D:\Anime',
        tasks: [task(state: 'metadata', displayName: 'Anime - 03.mkv')],
        fileDetailsByTaskId: const {'task': []},
        dirFileNames: const ['Anime - 03.mkv'],
      );

      var fileState = state.stateFor('Anime - 03.mkv');
      expect(fileState?.isActive, isTrue);
      expect(fileState?.statusLabel, '获取元数据');
    });

    test('keeps aria2 fallback for unknown files', () {
      var state = computeDirDownloadState(
        dir: r'D:\Anime',
        tasks: const [],
        fileDetailsByTaskId: const {},
        dirFileNames: const ['Anime - 02.mkv'],
        aria2FileNames: const ['Anime - 02.mkv'],
      );

      var fileState = state.stateFor('Anime - 02.mkv');
      expect(fileState?.isActive, isTrue);
      expect(fileState?.isIncomplete, isTrue);
      expect(fileState?.progress, isNull);
      expect(state.incompleteFileCount, 1);
    });

    test('prefers engine state over aria2 fallback', () {
      var state = computeDirDownloadState(
        dir: r'D:\Anime',
        tasks: [task(state: 'completed')],
        fileDetailsByTaskId: {
          'task': [file(filePath: 'Anime - 02.mkv')],
        },
        dirFileNames: const ['Anime - 02.mkv'],
        aria2FileNames: const ['Anime - 02.mkv'],
      );

      expect(state.stateFor('Anime - 02.mkv')?.isComplete, isTrue);
    });

    test('stateFor lookup is case insensitive', () {
      var state = computeDirDownloadState(
        dir: r'D:\Anime',
        tasks: [task(state: 'downloading')],
        fileDetailsByTaskId: {
          'task': [file(filePath: 'ANIME - 01.MKV')],
        },
        dirFileNames: const ['anime - 01.mkv'],
      );

      expect(state.stateFor('anime - 01.mkv')?.isActive, isTrue);
      expect(state.incompleteFileCount, 1);
    });

    test('counts paused and failed tasks as active tasks', () {
      var state = computeDirDownloadState(
        dir: r'D:\Anime',
        tasks: [task(state: 'paused')],
        fileDetailsByTaskId: {
          'task': [file()],
        },
        dirFileNames: const ['Anime - 01.mkv'],
      );

      expect(state.activeTaskCount, 1);
      expect(state.incompleteFileCount, 1);
    });
  });
}
