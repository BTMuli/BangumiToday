// Dart imports:
import 'dart:io';

// Project imports:
import '../../core/errors/playback_unavailable.dart';
import '../../core/services/bt_engine/protocol.dart';
import '../../core/services/file_service.dart';
import '../../core/utils/playback_paths.dart';
import '../../domain/repositories/playback_episode_links.dart';
import '../../models/playback/playback_item.dart';
import '../../store/bt_dir_download_state.dart';
import '../../tools/log_tool.dart';
import 'playback_library_impl.dart';

/// One directory/task snapshot shared by the file list and playback actions.
class SubjectLocalFiles {
  const SubjectLocalFiles({
    this.directory,
    this.files = const [],
    this.sizes = const {},
    this.downloadState,
    this.stateUnknown = false,
    this.playable = const [],
  });

  final String? directory;
  final List<String> files;
  final Map<String, int> sizes;
  final BtDirDownloadState? downloadState;
  final bool stateUnknown;
  final List<PlaybackItem> playable;
}

Future<SubjectLocalFiles> loadSubjectLocalFiles({
  required int subject,
  required String? directory,
  required Iterable<String> extraFiles,
  required List<BtTaskSnapshot> tasks,
  required Future<BtTaskFilesResult> Function(String id, int offset) taskFiles,
  required PlaybackEpisodeLinks links,
}) async {
  var files = directory == null
      ? <String>[]
      : await BTFileTool().getFileNames(directory, recursive: true);
  files.sort(PlaybackPaths.naturalCompare);
  var sizes = <String, int>{};
  for (var file in files) {
    var stat = await FileStat.stat(
      PlaybackPaths.resolveTaskPath(directory!, file),
    );
    if (stat.type == FileSystemEntityType.file) sizes[file] = stat.size;
  }
  var pages = <(String, int), Future<BtTaskFilesResult>>{};
  Future<BtTaskFilesResult> readPage(String id, int offset) async {
    try {
      return await (pages[(id, offset)] ??= taskFiles(id, offset));
    } catch (_) {
      throw const PlaybackUnavailable('下载文件状态尚未就绪');
    }
  }

  var details = <String, List<BtTaskFileDetail>>{};
  for (var task in tasks) {
    try {
      var entries = <BtTaskFileDetail>[];
      var offset = 0;
      while (true) {
        var page = await readPage(task.id, offset);
        entries.addAll(page.files);
        if (!page.truncated) break;
        var next = page.nextOffset;
        if (next == null || next <= offset) {
          throw const PlaybackUnavailable('下载文件列表分页尚未就绪');
        }
        offset = next;
      }
      details[task.id] = entries;
    } on PlaybackUnavailable {
      BTLogTool.warn('刷新详情页文件下载状态失败');
    }
  }
  var library = PlaybackLibraryImpl(
    tasks: () => tasks,
    taskFiles: readPage,
    links: links,
    episodes: (_) async => [],
  );
  var playable = await library.discoverFiles(
    [
      for (var file in files) PlaybackPaths.resolveTaskPath(directory!, file),
      ...extraFiles,
    ],
    subject: subject,
    taskFiles: details,
  );
  var root = directory == null ? null : PlaybackItem.pathKey(directory);
  return SubjectLocalFiles(
    directory: directory,
    files: files,
    sizes: sizes,
    downloadState: directory == null
        ? null
        : computeDirDownloadState(
            dir: directory,
            tasks: tasks,
            fileDetailsByTaskId: details,
            dirFileNames: files,
          ),
    stateUnknown: tasks.any(
      (task) =>
          PlaybackItem.pathKey(task.savePath) == root &&
          !details.containsKey(task.id),
    ),
    playable: playable,
  );
}
