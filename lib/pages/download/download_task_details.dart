// Dart imports:
import 'dart:async';
import 'dart:math';
import 'dart:ui' show PathMetric;

// Flutter imports:
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';

// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;

// Project imports:
import '../../core/services/bt_engine_client.dart';
import '../../core/services/file_service.dart';
import '../../core/theme/bt_theme.dart';
import '../../core/utils/playback_paths.dart';
import '../../store/bt_download_store.dart';
import '../../store/nav_store.dart';
import '../../ui/bt_infobar.dart';
import '../playback/playback_actions.dart';
import 'download_file_pager.dart';
import 'download_file_rates.dart';

part 'download_task_details/empty_state.dart';
part 'download_task_details/files_tab.dart';
part 'download_task_details/overview_tab.dart';
part 'download_task_details/peers_tab.dart';
part 'download_task_details/progress_tab.dart';
part 'download_task_details/tab_bar.dart';
part 'download_task_details/table_widgets.dart';
part 'download_task_details/tracker_graph.dart';
part 'download_task_details/trackers_tab.dart';

class DownloadTaskDetails extends ConsumerStatefulWidget {
  const DownloadTaskDetails({
    required this.taskId,
    required this.initialTask,
    super.key,
  });

  final String taskId;
  final BtTaskSnapshot initialTask;

  @override
  ConsumerState<DownloadTaskDetails> createState() =>
      _DownloadTaskDetailsState();
}

class _DownloadTaskDetailsState extends ConsumerState<DownloadTaskDetails> {
  BtTaskDetails? _details;
  DownloadFilePage? _files;
  final DownloadFilePager _filePager = DownloadFilePager();
  final DownloadFileRates _fileRates = DownloadFileRates();
  final Stopwatch _fileRateClock = Stopwatch()..start();
  Map<int, int?> _fileDownloadRates = {};
  BtTaskPeersResult? _peers;
  BtTaskTrackersResult? _trackers;
  Object? _error;
  final Map<int, String> _tabErrors = {};
  Timer? _refreshTimer;
  var _loading = true;
  var _tabIndex = 0;
  var _detailsLoading = false;
  var _filesLoading = false;
  var _fileSelectionBusy = false;
  bool? _fileBulkInclude;
  var _peersLoading = false;
  var _trackersLoading = false;
  var _peerRequest = 0;
  var _trackerRequest = 0;
  String? _peerTrackerUrl;
  String? _trackerPeerEndpoint;
  var _reannouncing = false;
  var _routeActive = false;

  static const _peerTabIndex = 2;
  static const _filesTabIndex = 3;
  static const _trackersTabIndex = 4;
  static const _filePageSize = 50;
  static const _peerPageSize = 100;

  bool get _tabLoading => switch (_tabIndex) {
    _peerTabIndex => _peersLoading,
    _filesTabIndex => _filesLoading,
    _trackersTabIndex => _trackersLoading,
    _ => _detailsLoading,
  };

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 桌面窗口失焦时路由仍为当前路由，详情应继续实时刷新。
    var routeActive = ModalRoute.isCurrentOf(context) ?? true;
    if (_routeActive == routeActive) return;
    _routeActive = routeActive;
    if (!_routeActive) {
      _resetFileRates();
      _stopRefreshTimer();
      return;
    }
    _startRefreshTimer();
    unawaited(_refresh());
  }

  @override
  void dispose() {
    _stopRefreshTimer();
    super.dispose();
  }

  void _startRefreshTimer() {
    if (_refreshTimer != null) return;
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => unawaited(_refresh(silent: true)),
    );
  }

  void _stopRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  bool get _engineReady =>
      ref.read(btDownloadStoreProvider).engineState ==
      BtEngineClientState.ready;

  Future<void> _refresh({bool silent = false}) async {
    if (!_routeActive || !_engineReady) return;
    var store = ref.read(btDownloadStoreProvider.notifier);
    // 当前可见 Tab 各自拉取，互不等待，避免切 Tab 被 overview 请求堵住。
    switch (_tabIndex) {
      case _peerTabIndex:
        await _loadPeers(store);
      case _filesTabIndex:
        await _loadFiles(store);
      case _trackersTabIndex:
        await _loadTrackers(store);
      default:
        await _loadDetails(store, silent: silent);
    }
  }

  Future<void> _loadDetails(
    BtDownloadStore store, {
    bool silent = false,
  }) async {
    if (!_routeActive || !_engineReady || _detailsLoading) return;
    _detailsLoading = true;
    if (!silent && mounted) setState(() => _loading = _details == null);
    try {
      var details = await store.taskDetails(widget.taskId);
      if (!mounted) return;
      setState(() {
        _details = details;
        _error = null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    } finally {
      _detailsLoading = false;
    }
  }

  Future<void> _loadFiles(BtDownloadStore store, {int? offset}) async {
    if (!_routeActive ||
        !_engineReady ||
        _filesLoading ||
        _fileSelectionBusy ||
        _fileBulkInclude != null) {
      return;
    }
    setState(() => _filesLoading = true);
    try {
      var files = await _filePager.load(
        readWindow: (offset, limit) =>
            store.taskFiles(widget.taskId, offset: offset, limit: limit),
        offset: offset ?? _files?.offset ?? 0,
        pageSize: _filePageSize,
      );
      if (!mounted) return;
      var task =
          ref.read(btDownloadStoreProvider).tasksById[widget.taskId] ??
          _details?.task ??
          widget.initialTask;
      setState(() {
        _fileDownloadRates = _fileRates.sample(
          files,
          sampledAt: _fileRateClock.elapsed,
          downloading:
              _routeActive &&
              _tabIndex == _filesTabIndex &&
              task.state == 'downloading',
        );
        _files = files;
        _tabErrors.remove(_filesTabIndex);
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _resetFileRates();
        _tabErrors[_filesTabIndex] = error.toString();
      });
    } finally {
      if (mounted) setState(() => _filesLoading = false);
    }
  }

  void _resetFileRates() {
    _fileRates.reset();
    _fileDownloadRates = {};
  }

  void _onFileSelectionBusyChanged(bool busy) {
    if (!mounted || _fileSelectionBusy == busy) return;
    setState(() => _fileSelectionBusy = busy);
  }

  Future<void> _setFilePageIncluded(bool include) async {
    var page = _files;
    if (page == null ||
        page.files.isEmpty ||
        _filesLoading ||
        _fileSelectionBusy ||
        _fileBulkInclude != null) {
      return;
    }
    setState(() => _fileBulkInclude = include);
    try {
      var applied = await ref
          .read(btDownloadStoreProvider.notifier)
          .setFilePriorities(widget.taskId, {
            for (var index in page.indices) index: include ? 4 : 0,
          });
      if (!mounted) return;
      setState(() => _files = page.withPriorities(applied));
    } catch (error) {
      if (mounted) unawaited(BtInfobar.error(context, '文件选择更新失败：$error'));
    } finally {
      if (mounted) setState(() => _fileBulkInclude = null);
    }
  }

  Widget? _fileActions(BtTaskSnapshot task) {
    if (task.sourceKind == 'http' ||
        {'completed', 'seeding'}.contains(task.state) ||
        _files?.files.isNotEmpty != true) {
      return null;
    }
    var busy = _filesLoading || _fileSelectionBusy || _fileBulkInclude != null;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var include in [true, false])
          Tooltip(
            message: _fileBulkInclude == include
                ? '正在更新文件选择'
                : include
                ? '下载本页全部文件'
                : '跳过本页全部文件',
            child: IconButton(
              icon: _fileBulkInclude == include
                  ? const SizedBox.square(
                      dimension: 14,
                      child: ProgressRing(strokeWidth: 2),
                    )
                  : Icon(
                      include ? FluentIcons.accept : FluentIcons.clear,
                      size: 14,
                    ),
              onPressed: busy
                  ? null
                  : () => unawaited(_setFilePageIncluded(include)),
            ),
          ),
      ],
    );
  }

  Future<void> _loadPeers(BtDownloadStore store, {int? offset}) async {
    if (!_routeActive || !_engineReady || _peersLoading) return;
    var request = ++_peerRequest;
    var trackerUrl = _peerTrackerUrl;
    setState(() => _peersLoading = true);
    try {
      var peers = await store.taskPeers(
        widget.taskId,
        offset: offset ?? _peers?.offset ?? 0,
        limit: _peerPageSize,
        trackerUrl: trackerUrl,
      );
      // 连接数变化使当前窗口失效时回到首页，不展示无法返回的空页。
      if (peers.offset > 0 && peers.peers.isEmpty) {
        peers = await store.taskPeers(
          widget.taskId,
          limit: _peerPageSize,
          trackerUrl: trackerUrl,
        );
      }
      if (!mounted || request != _peerRequest) return;
      setState(() {
        _peers = peers;
        _tabErrors.remove(_peerTabIndex);
      });
    } catch (error) {
      if (!mounted || request != _peerRequest) return;
      setState(() => _tabErrors[_peerTabIndex] = error.toString());
    } finally {
      if (mounted && request == _peerRequest) {
        setState(() => _peersLoading = false);
      }
    }
  }

  Future<void> _loadTrackers(BtDownloadStore store, {int? offset}) async {
    if (!_routeActive || !_engineReady || _trackersLoading) return;
    var request = ++_trackerRequest;
    var peerEndpoint = _trackerPeerEndpoint;
    setState(() => _trackersLoading = true);
    try {
      var trackers = await store.taskTrackers(
        widget.taskId,
        offset: offset ?? _trackers?.offset ?? 0,
        peerEndpoint: peerEndpoint,
      );
      if (trackers.offset > 0 && trackers.trackers.isEmpty) {
        trackers = await store.taskTrackers(
          widget.taskId,
          peerEndpoint: peerEndpoint,
        );
      }
      if (!mounted || request != _trackerRequest) return;
      setState(() {
        _trackers = trackers;
        _tabErrors.remove(_trackersTabIndex);
      });
    } catch (error) {
      if (mounted && request == _trackerRequest) {
        setState(() => _tabErrors[_trackersTabIndex] = error.toString());
      }
    } finally {
      if (mounted && request == _trackerRequest) {
        setState(() => _trackersLoading = false);
      }
    }
  }

  void _showPeersForTracker(String? url) {
    setState(() {
      _peerTrackerUrl = url;
      _peers = null;
      _peersLoading = false;
      ++_peerRequest;
      _tabErrors.remove(_peerTabIndex);
      _tabIndex = _peerTabIndex;
    });
    unawaited(
      _loadPeers(ref.read(btDownloadStoreProvider.notifier), offset: 0),
    );
  }

  void _showTrackersForPeer(String? endpoint) {
    setState(() {
      _trackerPeerEndpoint = endpoint;
      _trackers = null;
      _trackersLoading = false;
      ++_trackerRequest;
      _tabErrors.remove(_trackersTabIndex);
      _tabIndex = _trackersTabIndex;
    });
    unawaited(
      _loadTrackers(ref.read(btDownloadStoreProvider.notifier), offset: 0),
    );
  }

  Future<void> _reannounce() async {
    if (_reannouncing || !_engineReady) return;
    setState(() => _reannouncing = true);
    var store = ref.read(btDownloadStoreProvider.notifier);
    try {
      await store.reannounce(widget.taskId);
      if (!mounted) return;
      await _loadTrackers(store);
      if (mounted) {
        await BtInfobar.success(context, '已请求重新汇报，将遵守 Tracker 的最小间隔');
      }
    } catch (error) {
      if (mounted) await BtInfobar.error(context, '重新汇报失败：$error');
    } finally {
      if (mounted) setState(() => _reannouncing = false);
    }
  }

  void _onTabChanged(int index) {
    if (index == _tabIndex) return;
    setState(() {
      _resetFileRates();
      _tabIndex = index;
    });
    // 立即按目标 Tab 拉数，不复用可能正在跑的其它 Tab 请求。
    unawaited(_refresh(silent: true));
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(
      btDownloadStoreProvider.select(
        (store) => (store.tasksById[widget.taskId]?.state, store.engineState),
      ),
      (_, _) => setState(_resetFileRates),
    );
    var snapshot = ref.watch(
      btDownloadStoreProvider.select((store) {
        for (var item in store.tasks) {
          if (item.id == widget.taskId) return item;
        }
        return null;
      }),
    );
    var task = snapshot ?? _details?.task ?? widget.initialTask;
    var isDark = FluentTheme.of(context).brightness == Brightness.dark;
    if (_loading && _details == null) {
      return const Center(child: ProgressRing());
    }
    if (_details == null) {
      return _DetailError(error: _error, onRetry: _refresh);
    }
    return ColoredBox(
      color: BTColors.surfaceSecondary(context).withValues(alpha: 0.28),
      child: Column(
        children: [
          _DetailsHero(task: task),
          _DetailTabBar(
            tabs: [
              const _DetailTab(icon: FluentIcons.info, label: '信息'),
              const _DetailTab(icon: FluentIcons.processing, label: '进度'),
              _DetailTab(
                icon: FluentIcons.people,
                label: 'Peer ${_details!.totalPeers}',
              ),
              _DetailTab(icon: FluentIcons.folder, label: _filesTabLabel),
              const _DetailTab(icon: FluentIcons.link, label: 'Tracker'),
            ],
            index: _tabIndex,
            onChanged: _onTabChanged,
            trailing: Tooltip(
              message: '刷新详情',
              child: IconButton(
                icon: const Icon(FluentIcons.refresh, size: 14),
                onPressed: _tabLoading
                    ? null
                    : () => unawaited(_refresh(silent: true)),
              ),
            ),
          ),
          if (_tabIndex == _filesTabIndex && _files != null)
            _DetailPager(
              key: const ValueKey('files-pager'),
              offset: _files!.offset,
              count: _files!.files.length,
              total: _files!.totalFiles,
              nextOffset: _files!.nextOffset,
              pageSize: _filePageSize,
              loading:
                  _filesLoading ||
                  _fileSelectionBusy ||
                  _fileBulkInclude != null,
              description: '',
              actions: _fileActions(task),
              onPage: (offset) => unawaited(
                _loadFiles(
                  ref.read(btDownloadStoreProvider.notifier),
                  offset: offset,
                ),
              ),
            ),
          if (_tabIndex == _peerTabIndex && _peers != null)
            _DetailPager(
              key: const ValueKey('peers-pager'),
              offset: _peers!.offset,
              count: _peers!.peers.length,
              total: _peers!.totalPeers,
              nextOffset: _peers!.nextOffset,
              pageSize: _peerPageSize,
              loading: _peersLoading,
              description: '动态连接窗口；排序和客户端筛选仅作用于本页',
              onPage: (offset) => unawaited(
                _loadPeers(
                  ref.read(btDownloadStoreProvider.notifier),
                  offset: offset,
                ),
              ),
            ),
          if (_tabIndex == _trackersTabIndex && _trackers != null)
            _DetailPager(
              key: const ValueKey('trackers-pager'),
              offset: _trackers!.offset,
              count: _trackers!.trackers.length,
              total: _trackers!.totalTrackers,
              nextOffset: _trackers!.nextOffset,
              pageSize: 100,
              loading: _trackersLoading,
              description: 'Tracker 按接口与协议计数',
              onPage: (offset) => unawaited(
                _loadTrackers(
                  ref.read(btDownloadStoreProvider.notifier),
                  offset: offset,
                ),
              ),
            ),
          if (_tabIndex == _peerTabIndex && _peerTrackerUrl != null)
            _AssociationFilterBar(
              label: '关联 Tracker',
              value: _peerTrackerUrl!,
              onClear: () => _showPeersForTracker(null),
              onBack: () => _onTabChanged(_trackersTabIndex),
              backLabel: '返回 Tracker',
            ),
          if (_tabIndex == _trackersTabIndex && _trackerPeerEndpoint != null)
            _AssociationFilterBar(
              label: '关联 Peer',
              value: _trackerPeerEndpoint!,
              onClear: () => _showTrackersForPeer(null),
              onBack: () => _onTabChanged(_peerTabIndex),
              backLabel: '返回 Peer',
            ),
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: IndexedStack(
                    index: _tabIndex,
                    children: [
                      _OverviewTab(
                        task: task,
                        details: _details!,
                        fileCount:
                            _files?.contentFileCount ??
                            _details!.contentFileCount,
                      ),
                      _ProgressTab(task: task, details: _details!),
                      _PeersTab(
                        key: ValueKey(_peerTrackerUrl),
                        peers: _peers?.peers ?? const [],
                        truncated: _peers?.truncated ?? false,
                        loading: _peers == null && _peersLoading,
                        error: _tabErrors[_peerTabIndex],
                        trackerUrl: _peerTrackerUrl,
                        onShowTrackers: _showTrackersForPeer,
                        onRetry: () => unawaited(
                          _loadPeers(
                            ref.read(btDownloadStoreProvider.notifier),
                          ),
                        ),
                      ),
                      _FilesTab(
                        key: ValueKey(widget.taskId),
                        files: _files?.files ?? const [],
                        indices: _files?.indices ?? const [],
                        downloadRates: _fileDownloadRates,
                        offset: _files?.offset ?? 0,
                        selecting: _fileBulkInclude != null,
                        onSelectionBusyChanged: _onFileSelectionBusyChanged,
                        truncated: _files?.truncated ?? false,
                        totalFiles:
                            _files?.totalFiles ?? _details!.contentFileCount,
                        task: task,
                        taskId: widget.taskId,
                        loading: _files == null && _filesLoading,
                        error: _tabErrors[_filesTabIndex],
                        onRetry: () => unawaited(
                          _loadFiles(
                            ref.read(btDownloadStoreProvider.notifier),
                          ),
                        ),
                      ),
                      TickerMode(
                        enabled: _tabIndex == _trackersTabIndex && _routeActive,
                        child: _TrackersTab(
                          trackers: _trackers?.trackers ?? const [],
                          loading: _trackers == null && _trackersLoading,
                          error: _tabErrors[_trackersTabIndex],
                          peerEndpoint: _trackerPeerEndpoint,
                          onShowPeers: _showPeersForTracker,
                          isHttp: task.sourceKind == 'http',
                          reannouncing: _reannouncing,
                          canReannounce:
                              _engineReady &&
                              !{
                                'paused',
                                'stopped',
                                'error',
                                'completed',
                              }.contains(task.state),
                          onReannounce: () => unawaited(_reannounce()),
                          onRetry: () => unawaited(
                            _loadTrackers(
                              ref.read(btDownloadStoreProvider.notifier),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: 14,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: const [0, 0.5, 1],
                          colors: [
                            Colors.black.withValues(
                              alpha: isDark ? 0.30 : 0.12,
                            ),
                            Colors.black.withValues(
                              alpha: isDark ? 0.18 : 0.07,
                            ),
                            Colors.black.withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String get _filesTabLabel {
    var files = _files;
    if (files == null) return '文件 ${_details!.contentFileCount}';
    var total = files.contentFileCount;
    if (files.offset > 0 || files.truncated) return '文件 $total';
    var selectedCount = files.files
        .where((file) => !file.isPadding && !file.isSkipped)
        .length;
    return selectedCount == total ? '文件 $total' : '文件 $selectedCount/$total';
  }
}

class _DetailsHero extends StatelessWidget {
  const _DetailsHero({required this.task});

  final BtTaskSnapshot task;

  @override
  Widget build(BuildContext context) {
    var title = task.displayName.isEmpty
        ? task.displayInfoHash ?? task.id
        : task.displayName;
    var color = _taskStateColor(context, task.state);
    var progress = (task.progress * 100).clamp(0, 100).toDouble();
    return Container(
      padding: EdgeInsets.fromLTRB(22, 18, 22, 16),
      decoration: BoxDecoration(
        color: BTColors.surfacePrimary(context),
        border: Border(bottom: BorderSide(color: BTColors.divider(context))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BTRadius.largeBR,
                ),
                child: Icon(_taskStateIcon(task.state), size: 21, color: color),
              ),
              SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: BTTypography.subtitle(context),
                    ),
                    SizedBox(height: 5),
                    Row(
                      children: [
                        Icon(
                          FluentIcons.folder_open,
                          size: 12,
                          color: BTColors.textTertiary(context),
                        ),
                        SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            task.savePath,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: BTTypography.caption(context),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(width: 10),
              _StateBadge(state: task.state, color: color),
            ],
          ),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BTRadius.roundBR,
                  child: ProgressBar(
                    value: progress,
                    strokeWidth: 7,
                    activeColor: color,
                    backgroundColor: color.withValues(alpha: 0.1),
                  ),
                ),
              ),
              SizedBox(width: 12),
              Text(
                '${progress.toStringAsFixed(1)}%',
                style: BTTypography.bodyStrong(context).copyWith(color: color),
              ),
            ],
          ),
          SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _HeroMetric(
                  icon: FluentIcons.download,
                  label: '下载速度',
                  value: '${BTFileTool.formatSize(task.downloadRate)}/s',
                  color: FluentTheme.of(context).accentColor,
                ),
              ),
              SizedBox(width: 8),
              if (task.sourceKind == 'http')
                Expanded(
                  child: _HeroMetric(
                    icon: FluentIcons.database,
                    label: '已下载',
                    value:
                        '${BTFileTool.formatSize(task.downloadedBytes)} / ${BTFileTool.formatSize(task.totalBytes)}',
                    color: BTColors.info,
                  ),
                )
              else ...[
                Expanded(
                  child: _HeroMetric(
                    icon: FluentIcons.upload,
                    label: '上传速度',
                    value: '${BTFileTool.formatSize(task.uploadRate)}/s',
                    color: BTColors.successLight(context),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: _HeroMetric(
                    icon: FluentIcons.upload,
                    label: '分享率 / 做种',
                    value:
                        '${task.shareRatio.toStringAsFixed(2)} / ${_durationLabel(task.seedingSeconds)}',
                    color: BTColors.warningLight(context),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: BTColors.surfaceSecondary(context).withValues(alpha: 0.72),
        borderRadius: BTRadius.mediumBR,
        border: Border.all(color: BTColors.divider(context)),
      ),
      child: Row(
        children: [
          Container(
            width: 27,
            height: 27,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BTRadius.smallBR,
            ),
            child: Icon(icon, size: 13, color: color),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: BTTypography.caption(context)),
                SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: BTTypography.caption(context).copyWith(
                    color: BTColors.textPrimary(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StateBadge extends StatelessWidget {
  const _StateBadge({required this.state, required this.color});

  final String state;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BTRadius.roundBR,
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        _stateLabel(state),
        style: BTTypography.caption(
          context,
        ).copyWith(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _DetailError extends StatelessWidget {
  const _DetailError({required this.error, required this.onRetry});

  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: BTColors.errorLight(context).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              FluentIcons.error,
              size: 28,
              color: BTColors.errorLight(context),
            ),
          ),
          SizedBox(height: 14),
          Text('无法读取任务详情', style: BTTypography.subtitle(context)),
          SizedBox(height: 5),
          Text(
            error?.toString() ?? '未知错误',
            textAlign: TextAlign.center,
            style: BTTypography.caption(context),
          ),
          SizedBox(height: 14),
          Button(onPressed: onRetry, child: const Text('重新加载')),
        ],
      ),
    );
  }
}

Color _taskStateColor(BuildContext context, String state) {
  return switch (state) {
    'downloading' => FluentTheme.of(context).accentColor,
    'seeding' || 'completed' => BTColors.successLight(context),
    'metadata' => BTColors.info,
    'checking' || 'queued' => BTColors.warningLight(context),
    'error' => BTColors.errorLight(context),
    _ => BTColors.textTertiary(context),
  };
}

IconData _taskStateIcon(String state) {
  return switch (state) {
    'downloading' => FluentIcons.download,
    'seeding' => FluentIcons.upload,
    'completed' => FluentIcons.check_mark,
    'paused' => FluentIcons.pause,
    'stopped' => FluentIcons.stop,
    'error' => FluentIcons.error,
    'metadata' || 'checking' => FluentIcons.processing,
    _ => FluentIcons.clock,
  };
}

String _stateLabel(String state) {
  return switch (state) {
    'metadata' => '获取元数据',
    'checking' => '校验中',
    'queued' => '排队中',
    'downloading' => '下载中',
    'seeding' => '做种中',
    'paused' => '已暂停',
    'stopped' => '已停止',
    'completed' => '已完成',
    'error' => '发生错误',
    _ => state,
  };
}

String _sourceKindLabel(String sourceKind) {
  return switch (sourceKind) {
    'torrentFile' => 'Torrent 文件',
    'magnet' => 'Magnet 磁力链接',
    'http' => 'HTTP(S) 文件链接',
    _ => sourceKind,
  };
}

String _durationLabel(int seconds) {
  var duration = Duration(seconds: seconds);
  if (duration.inHours > 0) {
    return '${duration.inHours} 小时 ${duration.inMinutes.remainder(60)} 分钟';
  }
  return '${duration.inMinutes} 分钟 ${duration.inSeconds.remainder(60)} 秒';
}
