// Package imports:
import 'package:path/path.dart' as path;

// Project imports:
import '../core/services/bt_engine/protocol.dart';

/// 单个文件在 BMF 下载目录中的展示状态。
class BtFileDownloadState {
  const BtFileDownloadState({
    this.isActive = false,
    this.isPaused = false,
    this.isFailed = false,
    this.isComplete = false,
    this.progress,
    required this.statusLabel,
  });

  /// 正在下载 / 排队 / 校验 / 获取元数据。
  final bool isActive;

  /// 已暂停且未完成。
  final bool isPaused;

  /// 下载出错且未完成。
  final bool isFailed;

  /// 已下载完成（任务可用或该文件字节已完整），可打开。
  final bool isComplete;

  /// 单文件展示进度 0..1；未知时为 null（UI 显示为不确定动画，
  /// 如 aria2 兜底）。
  final double? progress;

  /// 状态文案（下载中 / 校验中 / 已暂停 / 下载失败 等）。
  final String statusLabel;

  /// 是否未完成（不可打开）。
  bool get isIncomplete => !isComplete;
}

/// 某个下载目录的整体状态。
class BtDirDownloadState {
  const BtDirDownloadState({
    required this.byName,
    required this.activeTaskCount,
    required this.incompleteFileCount,
  });

  /// 文件名 -> 状态；键保留引擎 / 目录中的原始大小写，
  /// 请通过 [stateFor] 做大小写不敏感查询。
  final Map<String, BtFileDownloadState> byName;

  /// 目录下尚未完成（含暂停 / 失败）的引擎任务数。
  final int activeTaskCount;

  /// 目录扫描列表中可见的未完成文件数。
  final int incompleteFileCount;

  bool get hasActiveTasks => activeTaskCount > 0;

  bool get hasIncompleteFiles => incompleteFileCount > 0;

  /// 按文件名（大小写不敏感）查询状态；无引擎信息返回 null。
  BtFileDownloadState? stateFor(String fileName) {
    var direct = byName[fileName];
    if (direct != null) return direct;
    var lower = fileName.toLowerCase();
    for (var entry in byName.entries) {
      if (entry.key.toLowerCase() == lower) return entry.value;
    }
    return null;
  }
}

/// 任务是否已完成（文件可用）：做种 / 完成 / 已校验字节达到总量。
///
/// 语义与 `BtDownloadStore` 的“文件可用”判定保持一致。
bool isTaskAvailable(BtTaskSnapshot task) {
  return task.state == 'seeding' ||
      task.state == 'completed' ||
      (task.totalBytes > 0 && task.verifiedBytes >= task.totalBytes);
}

/// 计算 BMF 下载目录的下载状态（纯函数，无 IO）。
///
/// [dir] 与任务 `savePath` 做大小写不敏感的归一化比较；
/// [fileDetailsByTaskId] 为任务 id -> 引擎文件详情（来自 `taskFiles` RPC，可能为空），
/// 用于判定单个文件是否已完成并显示该文件的字节进度；
/// [dirFileNames] 为当前目录扫描到的文件名，用于统计可见未完成数；
/// [aria2FileNames] 为 `.aria2` 伴生文件对应的文件名，作为外部下载工具兜底。
BtDirDownloadState computeDirDownloadState({
  required String dir,
  required List<BtTaskSnapshot> tasks,
  required Map<String, List<BtTaskFileDetail>> fileDetailsByTaskId,
  Iterable<String> dirFileNames = const [],
  Iterable<String> aria2FileNames = const [],
}) {
  var normalizedDir = path.normalize(dir).toLowerCase();
  var visibleNames = dirFileNames.map((name) => name.toLowerCase()).toSet();
  var byName = <String, BtFileDownloadState>{};
  var activeTaskCount = 0;

  for (var task in tasks) {
    if (path.normalize(task.savePath).toLowerCase() != normalizedDir) continue;
    var files = fileDetailsByTaskId[task.id] ?? const <BtTaskFileDetail>[];
    if (isTaskAvailable(task)) {
      _markCompleteFiles(byName, files);
      continue;
    }
    activeTaskCount++;
    if (files.isEmpty) {
      // metadata / 未知阶段：尝试用任务展示名匹配目录文件。
      _markByDisplayName(byName, task, visibleNames);
      continue;
    }
    for (var file in files) {
      if (file.isPadding || file.isSkipped || file.path.isEmpty) continue;
      var name = path.basename(file.path);
      if (name.isEmpty) continue;
      _mergeFileState(byName, name, _fileStateForFile(task, file));
    }
  }

  for (var name in aria2FileNames) {
    if (name.isEmpty || byName.containsKey(name)) continue;
    byName[name] = const BtFileDownloadState(
      isActive: true,
      isPaused: false,
      isFailed: false,
      isComplete: false,
      statusLabel: '下载中',
    );
  }

  var incompleteFileCount = byName.entries.where((entry) {
    if (entry.value.isComplete) return false;
    return visibleNames.contains(entry.key.toLowerCase());
  }).length;

  return BtDirDownloadState(
    byName: byName,
    activeTaskCount: activeTaskCount,
    incompleteFileCount: incompleteFileCount,
  );
}

void _markCompleteFiles(
  Map<String, BtFileDownloadState> byName,
  List<BtTaskFileDetail> files,
) {
  for (var file in files) {
    if (file.isPadding || file.isSkipped || file.path.isEmpty) continue;
    var name = path.basename(file.path);
    if (name.isEmpty) continue;
    byName[name] = const BtFileDownloadState(
      isActive: false,
      isPaused: false,
      isFailed: false,
      isComplete: true,
      statusLabel: '已完成',
    );
  }
}

void _markByDisplayName(
  Map<String, BtFileDownloadState> byName,
  BtTaskSnapshot task,
  Set<String> visibleNames,
) {
  var displayName = path.basename(task.displayName);
  if (displayName.isEmpty) return;
  if (visibleNames.isNotEmpty &&
      !visibleNames.contains(displayName.toLowerCase())) {
    return;
  }
  _mergeFileState(
    byName,
    displayName,
    _fileStateForTask(task, progress: task.progress),
  );
}

BtFileDownloadState _fileStateForFile(
  BtTaskSnapshot task,
  BtTaskFileDetail file,
) {
  if (file.size > 0 && file.progress >= 1.0) {
    return const BtFileDownloadState(
      isActive: false,
      isPaused: false,
      isFailed: false,
      isComplete: true,
      statusLabel: '已完成',
    );
  }
  return _fileStateForTask(task, progress: file.progress);
}

BtFileDownloadState _fileStateForTask(BtTaskSnapshot task, {double? progress}) {
  if (isTaskAvailable(task)) {
    return const BtFileDownloadState(
      isActive: false,
      isPaused: false,
      isFailed: false,
      isComplete: true,
      statusLabel: '已完成',
    );
  }
  return switch (task.state) {
    'paused' => BtFileDownloadState(
      isPaused: true,
      progress: progress,
      statusLabel: '已暂停',
    ),
    'error' => BtFileDownloadState(
      isFailed: true,
      progress: progress,
      statusLabel: '下载失败',
    ),
    'metadata' => BtFileDownloadState(
      isActive: true,
      progress: progress,
      statusLabel: '获取元数据',
    ),
    'checking' => BtFileDownloadState(
      isActive: true,
      progress: progress,
      statusLabel: '校验中',
    ),
    'queued' => BtFileDownloadState(
      isActive: true,
      progress: progress,
      statusLabel: '排队中',
    ),
    _ => BtFileDownloadState(
      isActive: true,
      progress: progress,
      statusLabel: '下载中',
    ),
  };
}

/// 同名文件来自多个任务时，优先保留“更未完成”的状态（安全侧）。
void _mergeFileState(
  Map<String, BtFileDownloadState> byName,
  String name,
  BtFileDownloadState state,
) {
  var existing = byName[name];
  if (existing == null) {
    byName[name] = state;
    return;
  }
  if (existing.isComplete && !state.isComplete) {
    byName[name] = state;
  }
}
