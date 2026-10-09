// Dart imports:
import 'dart:io';

// Package imports:
import 'package:path/path.dart' as path;

// Project imports:
import '../../core/errors/playback_unavailable.dart';
import '../../core/services/bt_engine/protocol.dart';
import '../../core/utils/episode_num_extractor.dart';
import '../../core/utils/playback_episode_files.dart';
import '../../core/utils/playback_paths.dart';
import '../../domain/repositories/episode_mark_gateway.dart';
import '../../domain/repositories/playback_episode_links.dart';
import '../../domain/repositories/playback_library.dart';
import '../../models/playback/playback_item.dart';

/// 基于下载引擎任务快照的本地资源实现。
///
/// 不把预分配的磁盘空间当作已下载数据：文件必须存在、非空，
/// 且在有对应任务时匹配的文件已完成下载和校验。
class PlaybackLibraryImpl implements PlaybackLibrary {
  PlaybackLibraryImpl({
    required this.tasks,
    required this.taskFiles,
    required this.links,
    required this.episodes,
  });

  final PlaybackEpisodeLinks links;
  final Future<List<EpisodeMarkEpisode>> Function(int subject) episodes;

  @override
  Future<int?> nextEpisodeIndex(
    List<PlaybackItem> items,
    int currentIndex,
  ) async {
    if (currentIndex < 0 || currentIndex >= items.length) return null;
    var current = items[currentIndex];
    var subject = current.subject;
    var manual = await links.readAll();
    var rules = await links.readRules();
    var link = manual[current.key];
    if (link != null && (link.subject != subject || link.excluded)) return null;
    if (link == null &&
        !rules.any(
          (rule) => rule.subject == subject && rule.appliesTo(current.filePath),
        )) {
      var evidence = extractEpisodeNumber(current.filePath);
      if (evidence.kind != EpisodeNumberKind.single &&
          evidence.kind != EpisodeNumberKind.unknown) {
        return null;
      }
    }
    var chapters = subject == null
        ? const <EpisodeMarkEpisode>[]
        : await episodes(subject);
    return nextPlaybackEpisodeIndex(
      items: items,
      currentIndex: currentIndex,
      episodes: chapters,
      manualLinks: await links.readAll(),
      rules: await links.readRules(),
    );
  }

  /// 当前引擎任务快照读取器。
  final List<BtTaskSnapshot> Function() tasks;

  /// 任务文件详情分页读取器。
  final Future<BtTaskFilesResult> Function(String id, int offset) taskFiles;

  Future<List<BtTaskFileDetail>> _allFiles(String id) async {
    var result = <BtTaskFileDetail>[];
    var offset = 0;
    while (true) {
      var page = await taskFiles(id, offset);
      result.addAll(page.files);
      if (!page.truncated) return result;
      var next = page.nextOffset;
      if (next == null || next <= offset) {
        throw const PlaybackUnavailable('下载文件列表尚未就绪');
      }
      offset = next;
    }
  }

  @override
  Future<void> ensureReady(String filePath) async {
    await _ensureReady(filePath, {});
  }

  Future<int> _ensureReady(
    String filePath,
    Map<String, List<BtTaskFileDetail>> cachedFiles,
  ) async {
    if (!PlaybackPaths.isVideo(filePath)) {
      throw const PlaybackUnavailable('请选择支持的视频文件');
    }
    var file = File(filePath);
    if (!await file.exists()) {
      throw const PlaybackUnavailable('视频文件不存在，请刷新下载目录');
    }
    var length = await file.length();
    if (length <= 0) {
      throw const PlaybackUnavailable('视频文件尚未下载完成');
    }
    var key = PlaybackItem.pathKey(filePath);
    for (var task in List<BtTaskSnapshot>.of(tasks())) {
      // 已完成的手动种子任务只保留历史，重启后没有可查询文件的 handle。
      // 它们不再跟踪磁盘文件；HTTP 任务仍保留文件信息，需要继续校验。
      if (task.manual &&
          task.state == 'completed' &&
          task.sourceKind != 'http') {
        continue;
      }
      var root = PlaybackItem.pathKey(task.savePath);
      if (!path.isWithin(root, key)) continue;
      var files = cachedFiles[task.id] ??= await _allFiles(task.id);
      if (files.isEmpty) {
        throw const PlaybackUnavailable('等待下载任务的文件信息');
      }
      for (var entry in files) {
        if (entry.path.isEmpty) continue;
        var resolved = PlaybackPaths.resolveTaskPath(task.savePath, entry.path);
        if (PlaybackItem.pathKey(resolved) != key) continue;
        if (entry.isPadding ||
            task.state == 'checking' ||
            entry.isSkipped ||
            entry.size <= 0 ||
            length < entry.size ||
            entry.completedBytes < entry.size) {
          throw const PlaybackUnavailable('视频文件尚未完成下载或校验');
        }
      }
    }
    return length;
  }

  @override
  Future<List<PlaybackItem>> discover(String dir, {int? subject}) async {
    var directory = Directory(dir);
    if (!await directory.exists()) return [];
    var linked = await links.readAll();
    var items = <PlaybackItem>[];
    var cachedFiles = <String, List<BtTaskFileDetail>>{};
    await for (var entity in directory.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is! File || !PlaybackPaths.isVideo(entity.path)) continue;
      try {
        var size = await _ensureReady(entity.path, cachedFiles);
        items.add(
          PlaybackItem(
            filePath: path.absolute(entity.path),
            title: path.basename(entity.path),
            subject:
                linked[PlaybackItem.pathKey(entity.path)]?.subject ?? subject,
            sizeBytes: size,
          ),
        );
      } on PlaybackUnavailable {
        // Pending downloads are omitted until a subsequent refresh.
      }
    }
    items.sort((a, b) => PlaybackPaths.episodeCompare(a.filePath, b.filePath));
    return items;
  }
}
