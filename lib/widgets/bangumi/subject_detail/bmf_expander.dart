// Dart imports:
import 'dart:async';

// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_material_design_icons/flutter_material_design_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:url_launcher/url_launcher_string.dart';

// Project imports:
import '../../../core/services/bmf_rss_service.dart';
import '../../../core/services/bt_engine/protocol.dart';
import '../../../core/theme/bt_theme.dart';
import '../../../database/app/app_config.dart';
import '../../../database/app/app_rss.dart';
import '../../../models/database/app_bmf_model.dart';
import '../../../models/rss/rss.dart';
import '../../../store/app_store.dart';
import '../../../store/bt_dir_download_state.dart';
import '../../../store/bt_download_store.dart';
import '../../../tools/download_tool.dart';
import '../../../tools/file_tool.dart';
import '../../../tools/log_tool.dart';
import '../../../tools/notifier_tool.dart';
import '../../../ui/bt_dialog.dart';
import '../../../ui/bt_icon.dart';
import '../../../ui/bt_infobar.dart';
import '../../../utils/tool_func.dart';
import 'bmf_rss_data.dart';

part 'bmf_expander/actions.dart';

part 'bmf_expander/panel.dart';

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
  DateTime? _lastStoreRefreshAt;
  static const _minStoreRefreshInterval = Duration(seconds: 1);
  static const _fileDetailsMinInterval = Duration(seconds: 5);
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
    if (_refreshingFiles) return;
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
    }
  }

  /// 刷新该目录下引擎任务的文件详情缓存（非完成任务）。
  ///
  /// 文件详情只用于标记单个文件是否已完成，进度由任务快照实时驱动，
  /// 因此放宽拉取频率：距上次成功拉取不足 [_fileDetailsMinInterval] 时跳过。
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
    var now = DateTime.now();
    if (_lastStoreRefreshAt != null &&
        now.difference(_lastStoreRefreshAt!) < _minStoreRefreshInterval) {
      return;
    }
    _lastStoreRefreshAt = now;
    Future.microtask(_refreshStoreState);
  }

  void _onDownloadStoreChanged() {
    if (!mounted) return;
    _scheduleRefresh();
  }

  /// 响应 store 通知：进度已在 [build] 中由 `ref.watch` 实时重建，
  /// 这里仅负责发现新任务 id 时触发完整目录扫描。
  ///
  /// 常规快照更新不重复扫描目录、也不拉取文件详情，避免高频 RPC。
  Future<void> _refreshStoreState() async {
    var generation = ++_refreshGeneration;
    var store = ref.read(btDownloadStoreProvider);
    var currentIds = store.tasks.map((task) => task.id).toSet();
    var hasNewTask = !currentIds.containsAll(_knownTaskIds);
    _knownTaskIds
      ..clear()
      ..addAll(currentIds);
    if (!mounted || generation != _refreshGeneration) return;
    if (hasNewTask) {
      await refreshFiles();
    }
  }

  Widget buildFileItem(BuildContext context, String file) {
    var fileState = _dirState?.stateFor(file);
    var isIncomplete = fileState?.isIncomplete ?? aria2Files.contains(file);
    var isVideo = file.endsWith('.mp4') || file.endsWith('.mkv');
    var isTorrent = file.endsWith('.torrent');
    var statusLabel = fileState?.statusLabel ?? '下载中';

    return Container(
      margin: EdgeInsets.only(bottom: 6),
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: BTColors.surfaceSecondary(context),
        borderRadius: BTRadius.smallBR,
        border: Border.all(color: BTColors.divider(context), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                isTorrent
                    ? FluentIcons.file_code
                    : isVideo
                    ? FluentIcons.video
                    : FluentIcons.document,
                size: 16,
                color: isIncomplete
                    ? FluentTheme.of(context).accentColor
                    : BTColors.textSecondary(context),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Tooltip(
                  message: file,
                  child: Text(
                    file,
                    style: BTTypography.body(context),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 6),
          Row(
            children: [
              if (isIncomplete) ...[
                Expanded(
                  child: ProgressBar(
                    value: (fileState?.progress ?? 0) * 100,
                    strokeWidth: 2,
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  statusLabel,
                  style: BTTypography.caption(
                    context,
                  ).copyWith(color: _statusColor(context, fileState)),
                ),
                SizedBox(width: 8),
              ] else
                const Spacer(),
              _FileItemActions(
                file: file,
                dir: widget.downloadDir,
                isVideo: isVideo,
                isTorrent: isTorrent,
                canOpen: isVideo && !isIncomplete,
                isIncomplete: isIncomplete,
                onDelete: refreshFiles,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _statusColor(BuildContext context, BtFileDownloadState? fileState) {
    if (fileState == null || fileState.isActive) {
      return FluentTheme.of(context).accentColor;
    }
    if (fileState.isPaused) return BTColors.warningLight(context);
    if (fileState.isFailed) return BTColors.errorLight(context);
    return FluentTheme.of(context).accentColor;
  }

  Widget buildContent() {
    if (files.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text('没有找到任何文件', style: BTTypography.body(context)),
      );
    }

    if (!widget.contentScrollable || files.length <= 6) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: files.map((f) => buildFileItem(context, f)).toList(),
      );
    }

    return SizedBox(
      height: widget.maxHeight,
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: files.length,
        itemBuilder: (context, index) {
          return buildFileItem(context, files[index]);
        },
      ),
    );
  }

  Widget _buildCountBadge(BuildContext context, int count) {
    var accentColor = FluentTheme.of(context).accentColor;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: accentColor,
        ),
      ),
    );
  }

  Widget _buildDownloadingBadge(BuildContext context, String label) {
    var accentColor = FluentTheme.of(context).accentColor;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: accentColor,
        borderRadius: BTRadius.roundBR,
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
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

class BmfRssExpander extends ConsumerStatefulWidget {
  final AppBmfModel bmf;
  final bool isConfig;
  final double maxHeight;
  final Future<void> Function()? onDelete;
  final bool initiallyExpanded;
  final bool contentScrollable;
  final bool expandable;
  final ScrollController? contentScrollController;

  const BmfRssExpander({
    super.key,
    required this.bmf,
    required this.isConfig,
    required this.maxHeight,
    this.onDelete,
    this.initiallyExpanded = true,
    this.contentScrollable = true,
    this.expandable = true,
    this.contentScrollController,
  });

  @override
  ConsumerState<BmfRssExpander> createState() => _BmfRssExpanderState();
}

class _BmfRssExpanderState extends ConsumerState<BmfRssExpander> {
  late final BmfRssData _data = BmfRssData(
    sqlite: BtsAppRss(),
    bmf: widget.bmf,
  );
  StreamSubscription<BmfRssUpdateEvent>? _updateSubscription;

  String? get _updateKey {
    var bmf = widget.bmf;
    if (bmf.mkBgmId != null && bmf.mkBgmId!.isNotEmpty) return bmf.mkBgmId;
    return bmf.rss;
  }

  String? get mikanRss => ref.watch(appStoreProvider).mikanRss;

  @override
  void initState() {
    super.initState();
    _data.mikanRss = mikanRss;
    _data.addListener(_onDataChanged);
    _listenToUpdate();
    Future.microtask(_data.load);
  }

  void _onDataChanged() {
    if (mounted) setState(() {});
  }

  void _listenToUpdate() {
    var key = _updateKey;
    if (key == null) return;
    _updateSubscription = BmfRssService.instance.updateStream
        .where((event) => event.key == key)
        .listen((event) {
          if (!mounted || _updateKey != key) return;
          _data.applyUpdate(event);
        });
  }

  @override
  void didUpdateWidget(BmfRssExpander oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bmf.rss != widget.bmf.rss ||
        oldWidget.bmf.mkBgmId != widget.bmf.mkBgmId ||
        oldWidget.bmf.mkGroupId != widget.bmf.mkGroupId) {
      _updateSubscription?.cancel();
      _updateSubscription = null;
      _data.updateBmf(widget.bmf, mikanRss: mikanRss);
      _listenToUpdate();
    }
  }

  @override
  void dispose() {
    _updateSubscription?.cancel();
    _data.removeListener(_onDataChanged);
    _data.dispose();
    super.dispose();
  }

  Widget buildRssItem(BuildContext context, RssItem item) {
    var fileSize = item.enclosure?.length != null
        ? filesize(item.enclosure!.length)
        : null;
    var isPending = _data.pendingItemKeys.contains(_data.itemKey(item));
    var accentColor = FluentTheme.of(context).accentColor;

    return Container(
      margin: EdgeInsets.only(bottom: 6),
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isPending
            ? accentColor.withValues(alpha: 0.1)
            : BTColors.surfaceSecondary(context),
        borderRadius: BTRadius.smallBR,
        border: Border.all(
          color: isPending ? accentColor : BTColors.divider(context),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                MdiIcons.download,
                size: 16,
                color: isPending
                    ? accentColor
                    : BTColors.textSecondary(context),
              ),
              SizedBox(width: 8),
              if (isPending) ...[
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: BTRadius.roundBR,
                  ),
                  child: Text(
                    '新',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                SizedBox(width: 7),
              ],
              Expanded(
                child: Tooltip(
                  message: item.title ?? '',
                  child: Text(
                    item.title ?? '',
                    style: BTTypography.body(context),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 4),
          Row(
            children: [
              if (fileSize != null) ...[
                Icon(
                  FluentIcons.save,
                  size: 10,
                  color: BTColors.textTertiary(context),
                ),
                SizedBox(width: 4),
                Text(fileSize, style: BTTypography.caption(context)),
                SizedBox(width: 12),
              ],
              if (item.pubDate != null) ...[
                Icon(
                  FluentIcons.clock,
                  size: 10,
                  color: BTColors.textTertiary(context),
                ),
                SizedBox(width: 4),
                Text(
                  item.pubDate!.length > 10
                      ? item.pubDate!.substring(0, 10)
                      : item.pubDate!,
                  style: BTTypography.caption(context),
                ),
              ],
              const Spacer(),
              if (isPending)
                Tooltip(
                  message: '标记为已处理',
                  child: IconButton(
                    icon: BtIcon(FluentIcons.check_mark, size: 14),
                    onPressed: () => _data.markItemHandled(item),
                  ),
                ),
              _RssItemActions(
                item: item,
                dir: widget.bmf.download,
                subject: widget.bmf.subject,
                rssLink: widget.bmf.rss!,
                onHandled: () => _data.markItemHandled(item),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget buildContent() {
    if (_data.rssItems.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text('没有找到任何 RSS 信息', style: BTTypography.body(context)),
      );
    }

    if (!widget.contentScrollable || _data.rssItems.length <= 6) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: _data.rssItems
            .map((item) => buildRssItem(context, item))
            .toList(),
      );
    }

    return SizedBox(
      height: widget.maxHeight,
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: _data.rssItems.length,
        itemBuilder: (context, index) {
          return buildRssItem(context, _data.rssItems[index]);
        },
      ),
    );
  }

  Widget _buildCountBadge(BuildContext context, int count) {
    var accentColor = FluentTheme.of(context).accentColor;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: accentColor,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _data.mikanRss = mikanRss;
    var accentColor = FluentTheme.of(context).accentColor;
    var rssLink = _data.rssUrl;

    var header = Row(
      children: [
        Text('RSS 订阅', style: BTTypography.subtitle(context)),
        if (_data.rssItems.isNotEmpty) ...[
          SizedBox(width: 8),
          _buildCountBadge(context, _data.rssItems.length),
        ],
        if (_data.pendingItemKeys.isNotEmpty) ...[
          SizedBox(width: 8),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius: BTRadius.roundBR,
            ),
            child: Text(
              '${_data.pendingItemKeys.length} 条更新',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
        SizedBox(width: 8),
        Tooltip(
          message: rssLink,
          child: Icon(
            FluentIcons.info,
            size: 14,
            color: BTColors.textTertiary(context),
          ),
        ),
        const Spacer(),
        if (_data.pendingItemKeys.isNotEmpty)
          Tooltip(
            message: '全部标记为已处理',
            child: IconButton(
              icon: BtIcon(FluentIcons.clear_selection, size: 14),
              onPressed: _data.markAllHandled,
            ),
          ),
        if (widget.onDelete != null)
          Tooltip(
            message: '删除订阅',
            child: IconButton(
              icon: BtIcon(
                FluentIcons.delete,
                size: 14,
                color: FluentTheme.of(context).accentColor,
              ),
              onPressed: () async {
                var confirm = await showConfirm(
                  context,
                  title: '删除 RSS 订阅',
                  content: '确定删除该 RSS 订阅配置吗？',
                );
                if (!confirm) return;
                await widget.onDelete!();
              },
            ),
          ),
        Tooltip(
          message: '刷新 RSS',
          child: IconButton(
            icon: BtIcon(FluentIcons.refresh, size: 14),
            onPressed: () async {
              var result = await BmfRssService.instance.refreshBmf(widget.bmf);
              if (!context.mounted) return;
              if (result) {
                await BtInfobar.success(context, 'RSS 刷新成功');
              } else {
                await BtInfobar.error(context, 'RSS 刷新失败');
              }
            },
          ),
        ),
        Tooltip(
          message: '打开 RSS',
          child: IconButton(
            icon: BtIcon(FluentIcons.edge_logo, size: 14),
            onPressed: () async => await launchUrlString(rssLink),
          ),
        ),
      ],
    );

    if (!widget.expandable) {
      return _buildFixedResourcePanel(
        context,
        leading: Icon(MdiIcons.rss, size: 18, color: accentColor),
        header: header,
        content: buildContent(),
        controller: widget.contentScrollController,
      );
    }

    return Expander(
      initiallyExpanded: widget.initiallyExpanded,
      leading: Icon(MdiIcons.rss, size: 18, color: accentColor),
      header: header,
      content: buildContent(),
    );
  }
}
