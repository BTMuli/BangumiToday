part of '../bmf_expander.dart';

class BmfFileExpander extends ConsumerStatefulWidget {
  final String downloadDir;
  final int subject;
  final double maxHeight;
  final Future<void> Function()? onDelete;
  final bool contentScrollable;
  final bool expandable;
  final ScrollController? contentScrollController;

  const BmfFileExpander({
    super.key,
    required this.downloadDir,
    required this.subject,
    required this.maxHeight,
    this.onDelete,
    this.contentScrollable = true,
    this.expandable = true,
    this.contentScrollController,
  });

  @override
  ConsumerState<BmfFileExpander> createState() => _BmfFileExpanderState();
}

class _BmfFileExpanderState extends ConsumerState<BmfFileExpander> {
  final BTFileTool fileTool = BTFileTool();
  final BTNotifierTool notifierTool = BTNotifierTool();
  late final BtDownloadStore _downloadStore;
  List<String> files = [];
  List<String> aria2Files = [];
  final Map<String, List<BtTaskFileDetail>> _taskFileDetails = {};
  final Map<String, DateTime> _taskFileDetailsFetchedAt = {};
  final Set<String> _knownTaskIds = {};
  late Timer timerFiles;
  int _refreshGeneration = 0;
  bool _refreshingFiles = false;
  bool _refreshFilesQueued = false;
  DateTime? _lastStoreRefreshAt;
  bool _storeRefreshScheduled = false;
  static const _minStoreRefreshInterval = Duration(seconds: 1);
  static const _fileDetailsMinInterval = Duration(seconds: 1);
  BtDirDownloadState? _dirState;

  @override
  void initState() {
    super.initState();
    _downloadStore = ref.read(btDownloadStoreProvider);
    _knownTaskIds.addAll(_downloadStore.tasks.map((task) => task.id));
    _downloadStore.addListener(_onDownloadStoreChanged);
    timerFiles = getTimerFiles();
    Future.microtask(refreshFiles);
  }

  @override
  void didUpdateWidget(BmfFileExpander oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.downloadDir != widget.downloadDir) {
      _refreshGeneration++;
      files.clear();
      aria2Files.clear();
      Future.microtask(refreshFiles);
    }
  }

  @override
  void dispose() {
    _downloadStore.removeListener(_onDownloadStoreChanged);
    _refreshGeneration++;
    timerFiles.cancel();
    super.dispose();
  }

  Timer getTimerFiles() {
    return Timer.periodic(
      const Duration(seconds: 5),
      (timer) async => await refreshFiles(),
    );
  }

  Future<void> refreshFiles() async {
    if (_refreshingFiles) {
      _refreshFilesQueued = true;
      return;
    }
    _refreshingFiles = true;
    var generation = ++_refreshGeneration;
    var downloadDir = widget.downloadDir;
    var subject = widget.subject;
    try {
      var filesGet = await fileTool.getFileNames(downloadDir);
      if (!mounted || generation != _refreshGeneration) return;
      var aria2FilesGet = filesGet
          .where((element) => element.endsWith('.aria2'))
          .map((e) => e.replaceAll('.aria2', ''))
          .toList();
      await _refreshTaskFileDetails(downloadDir, generation);
      if (!mounted || generation != _refreshGeneration) return;
      var store = ref.read(btDownloadStoreProvider);
      var dirState = computeDirDownloadState(
        dir: downloadDir,
        tasks: store.tasks,
        fileDetailsByTaskId: _taskFileDetails,
        dirFileNames: filesGet,
        aria2FileNames: aria2FilesGet,
      );
      var keepPolling = dirState.hasActiveTasks || aria2FilesGet.isNotEmpty;
      if (keepPolling) {
        if (!timerFiles.isActive) timerFiles = getTimerFiles();
      } else if (timerFiles.isActive) {
        timerFiles.cancel();
      }
      if (aria2Files.isNotEmpty && aria2FilesGet != aria2Files) {
        var diffFiles = aria2Files
            .where((element) => !aria2FilesGet.contains(element))
            .toList();
        if (diffFiles.isNotEmpty) {
          for (var file in diffFiles) {
            var exist = await fileTool.isFileExist(
              path.join(downloadDir, file),
            );
            if (!mounted || generation != _refreshGeneration) return;
            if (!exist) continue;
            await notifierTool.showVideo(
              subject: subject,
              dir: downloadDir,
              file: file,
            );
            if (!mounted || generation != _refreshGeneration) return;
          }
        }
      }
      if (!mounted || generation != _refreshGeneration) return;
      setState(() {
        files = filesGet
            .where((element) => !element.endsWith('.aria2'))
            .toList();
        aria2Files = aria2FilesGet;
      });
    } finally {
      _refreshingFiles = false;
      if (_refreshFilesQueued && mounted) {
        _refreshFilesQueued = false;
        unawaited(refreshFiles());
      }
    }
  }

  /// 刷新该目录下引擎任务的文件详情缓存（非完成任务）。
  ///
  /// 文件详情同时提供单文件完成状态和单文件进度；限制拉取频率，避免
  /// 引擎快照高频更新时重复请求同一任务的文件列表。
  Future<void> _refreshTaskFileDetails(
    String downloadDir,
    int generation,
  ) async {
    var store = ref.read(btDownloadStoreProvider);
    var normalizedDir = path.normalize(downloadDir).toLowerCase();
    var matchedIds = <String>{};
    var refreshIds = <String>[];
    for (var task in store.tasks) {
      if (path.normalize(task.savePath).toLowerCase() != normalizedDir) {
        continue;
      }
      matchedIds.add(task.id);
      if (!isTaskAvailable(task)) refreshIds.add(task.id);
    }
    _taskFileDetails.removeWhere((id, _) => !matchedIds.contains(id));
    _taskFileDetailsFetchedAt.removeWhere((id, _) => !matchedIds.contains(id));
    for (var id in refreshIds) {
      if (!mounted || generation != _refreshGeneration) return;
      var lastFetchedAt = _taskFileDetailsFetchedAt[id];
      if (lastFetchedAt != null &&
          DateTime.now().difference(lastFetchedAt) < _fileDetailsMinInterval) {
        continue;
      }
      try {
        var result = await store.taskFiles(id);
        _taskFileDetails[id] = List.of(result.files);
        _taskFileDetailsFetchedAt[id] = DateTime.now();
      } catch (error) {
        _taskFileDetails.remove(id);
        _taskFileDetailsFetchedAt.remove(id);
        BTLogTool.warn('刷新 BMF 下载任务文件详情失败: $error');
      }
    }
  }

  /// store 通知后安排一次状态刷新（新任务出现时立即拉取文件详情）。
  void _scheduleRefresh() {
    var currentIds = _downloadStore.tasks.map((task) => task.id).toSet();
    var hasNewTask = !_knownTaskIds.containsAll(currentIds);
    var now = DateTime.now();
    if (!hasNewTask &&
        _lastStoreRefreshAt != null &&
        now.difference(_lastStoreRefreshAt!) < _minStoreRefreshInterval) {
      return;
    }
    _lastStoreRefreshAt = now;
    if (_storeRefreshScheduled) return;
    _storeRefreshScheduled = true;
    unawaited(
      Future<void>.microtask(() async {
        _storeRefreshScheduled = false;
        if (!mounted) return;
        await _refreshStoreState();
      }),
    );
  }

  void _onDownloadStoreChanged() {
    if (!mounted) return;
    _scheduleRefresh();
  }

  /// 响应 store 通知：刷新文件详情，让 BMF 文件级进度跟随引擎更新。
  ///
  /// 常规快照更新不重复扫描目录；新任务出现时才走完整目录扫描，
  /// 用于发现磁盘上的新文件。
  Future<void> _refreshStoreState() async {
    var generation = ++_refreshGeneration;
    var store = ref.read(btDownloadStoreProvider);
    var currentIds = store.tasks.map((task) => task.id).toSet();
    // 新任务出现在当前集合中，但不在已知集合中。
    var hasNewTask = !_knownTaskIds.containsAll(currentIds);
    _knownTaskIds
      ..clear()
      ..addAll(currentIds);
    if (!mounted || generation != _refreshGeneration) return;
    if (hasNewTask) {
      await refreshFiles();
      return;
    }
    await _refreshTaskFileDetails(widget.downloadDir, generation);
    if (!mounted || generation != _refreshGeneration) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    var accentColor = FluentTheme.of(context).accentColor;
    var store = ref.watch(btDownloadStoreProvider);
    _dirState = computeDirDownloadState(
      dir: widget.downloadDir,
      tasks: store.tasks,
      fileDetailsByTaskId: _taskFileDetails,
      dirFileNames: files,
      aria2FileNames: aria2Files,
    );
    var header = Row(
      children: [
        Text('下载目录', style: BTTypography.subtitle(context)),
        if (files.isNotEmpty) ...[
          SizedBox(width: 8),
          _buildCountBadge(context, files.length),
        ],
        if (_dirState != null && _dirState!.hasIncompleteFiles) ...[
          SizedBox(width: 8),
          _buildDownloadingBadge(
            context,
            '${_dirState!.incompleteFileCount} 个下载中',
          ),
        ] else if (_dirState != null && _dirState!.hasActiveTasks) ...[
          SizedBox(width: 8),
          _buildDownloadingBadge(
            context,
            '${_dirState!.activeTaskCount} 个任务下载中',
          ),
        ],
        SizedBox(width: 8),
        Tooltip(
          message: widget.downloadDir.isEmpty ? '未设置下载目录' : widget.downloadDir,
          child: Icon(
            FluentIcons.info,
            size: 14,
            color: BTColors.textTertiary(context),
          ),
        ),
        const Spacer(),
        if (widget.onDelete != null)
          Tooltip(
            message: '删除目录',
            child: IconButton(
              icon: BtIcon(
                FluentIcons.delete,
                size: 14,
                color: FluentTheme.of(context).accentColor,
              ),
              onPressed: () async {
                var confirm = await showConfirm(
                  context,
                  title: '删除下载目录',
                  content: '确定删除该下载目录配置吗？',
                );
                if (!confirm) return;
                await widget.onDelete!();
              },
            ),
          ),
        Tooltip(
          message: '刷新文件',
          child: IconButton(
            icon: BtIcon(FluentIcons.refresh, size: 14),
            onPressed: () async {
              if (widget.downloadDir.isEmpty) {
                await BtInfobar.error(context, '请先设置下载目录');
                return;
              }
              await refreshFiles();
              if (context.mounted) await BtInfobar.success(context, '刷新文件成功');
            },
          ),
        ),
        Tooltip(
          message: '打开目录',
          child: IconButton(
            icon: BtIcon(FluentIcons.folder, size: 14),
            onPressed: () async {
              if (widget.downloadDir.isEmpty) {
                await BtInfobar.error(context, '请先设置下载目录');
                return;
              }
              await fileTool.openDir(widget.downloadDir);
            },
          ),
        ),
      ],
    );

    if (!widget.expandable) {
      return _buildFixedResourcePanel(
        context,
        leading: Icon(FluentIcons.folder_open, size: 18, color: accentColor),
        header: header,
        content: buildContent(),
        controller: widget.contentScrollController,
      );
    }

    return Expander(
      leading: Icon(FluentIcons.folder_open, size: 18, color: accentColor),
      header: header,
      content: buildContent(),
    );
  }
}
