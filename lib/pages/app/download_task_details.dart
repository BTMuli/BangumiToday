import 'dart:async';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;

import '../../core/services/bt_engine_client.dart';
import '../../core/theme/bt_theme.dart';
import '../../store/bt_download_store.dart';
import '../../tools/file_tool.dart';
import '../../ui/bt_infobar.dart';

part 'download_task_details/empty_state.dart';
part 'download_task_details/files_tab.dart';
part 'download_task_details/overview_tab.dart';
part 'download_task_details/peers_tab.dart';
part 'download_task_details/progress_tab.dart';
part 'download_task_details/tab_bar.dart';
part 'download_task_details/table_widgets.dart';

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

class _DownloadTaskDetailsState extends ConsumerState<DownloadTaskDetails>
    with WidgetsBindingObserver {
  BtTaskDetails? _details;
  Object? _error;
  Timer? _refreshTimer;
  var _loading = true;
  var _tabIndex = 0;
  var _refreshing = false;
  var _appActive = true;

  static const _peerTabIndex = 2;
  static const _filesTabIndex = 3;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(_refresh);
    _startRefreshTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopRefreshTimer();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appActive = state == AppLifecycleState.resumed;
    if (!_appActive) {
      _stopRefreshTimer();
      return;
    }
    _startRefreshTimer();
    unawaited(_refresh(silent: true));
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
    if (!_appActive || !_engineReady || _refreshing) return;
    _refreshing = true;
    if (!silent && mounted) setState(() => _loading = true);
    try {
      var details = await ref
          .read(btDownloadStoreProvider)
          .taskDetails(widget.taskId);
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
      _refreshing = false;
    }
  }

  void _onTabChanged(int index) {
    if (index == _tabIndex) return;
    setState(() => _tabIndex = index);
    // Peer/文件列表只在对应 Tab 可见时拉取，经 single-flight 去重。
    if (index == _peerTabIndex || index == _filesTabIndex) {
      unawaited(_refresh(silent: true));
    }
  }

  BtTaskSnapshot _currentTask(BtDownloadStore store) {
    for (var task in store.tasks) {
      if (task.id == widget.taskId) return task;
    }
    return _details?.task ?? widget.initialTask;
  }

  @override
  Widget build(BuildContext context) {
    var store = ref.watch(btDownloadStoreProvider);
    var task = _currentTask(store);
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
                label: 'Peer ${_details!.peers.length}',
              ),
              _DetailTab(
                icon: FluentIcons.folder,
                label: '文件 ${_details!.files.length}',
              ),
            ],
            index: _tabIndex,
            onChanged: _onTabChanged,
            trailing: Tooltip(
              message: '刷新详情',
              child: IconButton(
                icon: const Icon(FluentIcons.refresh, size: 14),
                onPressed: _refreshing
                    ? null
                    : () => unawaited(_refresh(silent: true)),
              ),
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: IndexedStack(
                    index: _tabIndex,
                    children: [
                      _OverviewTab(task: task, details: _details!),
                      _ProgressTab(task: task, details: _details!),
                      _PeersTab(details: _details!),
                      _FilesTab(details: _details!),
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
    'completed' => '已完成',
    'error' => '发生错误',
    _ => state,
  };
}

String _sourceKindLabel(String sourceKind) {
  return switch (sourceKind) {
    'torrentFile' => 'Torrent 文件',
    'magnet' => 'Magnet 磁力链接',
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
