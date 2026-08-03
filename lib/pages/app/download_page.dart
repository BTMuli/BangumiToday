// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

// Project imports:
import '../../core/services/bt_engine_client.dart';
import '../../core/theme/bt_theme.dart';
import '../../store/bt_download_store.dart';
import '../../tools/file_tool.dart';
import '../../ui/bt_dialog.dart';
import '../../ui/bt_engine_switch.dart';
import '../../ui/bt_infobar.dart';
import '../../widgets/common/bt_buttons.dart';
import '../../widgets/common/bt_card.dart';
import '../../widgets/common/bt_drawer.dart';
import 'download_task_details.dart';

class DownloadPage extends ConsumerStatefulWidget {
  const DownloadPage({super.key});

  @override
  ConsumerState<DownloadPage> createState() => _DownloadPageState();
}

class _DownloadPageState extends ConsumerState<DownloadPage> {
  var _tabIndex = 0;
  var _selecting = false;
  final Set<String> _selectedIds = {};

  @override
  Widget build(BuildContext context) {
    var store = ref.watch(btDownloadStoreProvider);
    _pruneSelection(store);
    var activeTasks = store.activeTasks;
    var stoppedTasks = store.stoppedTasks;
    var tasks = _tabIndex == 0 ? activeTasks : stoppedTasks;
    return ScaffoldPage(
      header: PageHeader(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _PageTitle(
              activeCount: activeTasks.length,
              stoppedCount: stoppedTasks.length,
            ),
            SizedBox(width: 12.w),
            if (_selecting)
              _SelectionBar(
                count: _selectedIds.length,
                onSelectAll: tasks.isEmpty
                    ? null
                    : () => setState(() {
                        _selectedIds
                          ..clear()
                          ..addAll(tasks.map((task) => task.id));
                      }),
                onClear: _selectedIds.isEmpty
                    ? null
                    : () => setState(_selectedIds.clear),
                onDelete: _selectedIds.isEmpty ? null : _confirmBatchDelete,
                onCancel: _exitSelection,
              )
            else
              Tooltip(
                message: '批量选择',
                child: IconButton(
                  icon: const Icon(FluentIcons.check_list, size: 16),
                  onPressed: tasks.isEmpty
                      ? null
                      : () => setState(() {
                          _selecting = true;
                          _selectedIds.clear();
                        }),
                ),
              ),
          ],
        ),
        commandBar: Wrap(
          spacing: 6.w,
          runSpacing: 6.h,
          alignment: WrapAlignment.end,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _TotalRates(
              downloadRate: store.totalDownloadRate,
              uploadRate: store.totalUploadRate,
            ),
            BTSegmentedControl(
              selectedIndex: _tabIndex,
              options: [
                '进行中 ${activeTasks.length}',
                '已停止 ${stoppedTasks.length}',
              ],
              onChanged: (index) => setState(() => _tabIndex = index),
            ),
            _EngineStatus(
              state: store.engineState,
              onEnable: () => _enableEngine(context),
            ),
            Tooltip(
              message: '刷新任务',
              child: IconButton(
                icon: store.refreshing
                    ? const SizedBox.square(
                        dimension: 16,
                        child: ProgressRing(strokeWidth: 2),
                      )
                    : const Icon(FluentIcons.refresh, size: 16),
                onPressed: store.refreshing ? null : () => _refresh(context),
              ),
            ),
          ],
        ),
      ),
      content: Container(
        color: BTColors.surfaceSecondary(context).withValues(alpha: 0.34),
        child: _buildContent(context, store, tasks),
      ),
    );
  }

  void _pruneSelection(BtDownloadStore store) {
    if (_selectedIds.isEmpty) return;
    var knownIds = store.tasks.map((task) => task.id).toSet();
    var stale = _selectedIds.difference(knownIds);
    if (stale.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _selectedIds.removeAll(stale);
        if (_selectedIds.isEmpty) _selecting = false;
      });
    });
  }

  Future<void> _refresh(BuildContext context) async {
    try {
      await ref.read(btDownloadStoreProvider).refresh();
      if (context.mounted) {
        await BtInfobar.success(context, '下载任务已刷新');
      }
    } catch (error) {
      if (context.mounted) await BtInfobar.error(context, error.toString());
    }
  }

  Future<void> _enableEngine(BuildContext context) async {
    await enableDownloadEngine(ref, context);
  }

  void _exitSelection() {
    setState(() {
      _selecting = false;
      _selectedIds.clear();
    });
  }

  void _toggleSelect(String id) {
    setState(() {
      if (!_selectedIds.remove(id)) _selectedIds.add(id);
    });
  }

  Future<void> _confirmBatchDelete() async {
    var knownIds = ref
        .read(btDownloadStoreProvider)
        .tasks
        .map((task) => task.id)
        .toSet();
    var targets = _selectedIds.intersection(knownIds);
    if (targets.isEmpty) return;
    var confirmed = await showConfirm(
      context,
      title: '批量删除所选任务？',
      content: '将删除已选择的 ${targets.length} 个任务，已下载的数据会保留。',
    );
    if (!confirmed || !mounted) return;
    try {
      await ref.read(btDownloadStoreProvider).removeAll(targets);
      if (!mounted) return;
      _exitSelection();
      await BtInfobar.success(context, '已删除 ${targets.length} 个任务');
    } catch (error) {
      if (mounted) await BtInfobar.error(context, error.toString());
    }
  }

  Widget _buildContent(
    BuildContext context,
    BtDownloadStore store,
    List<BtTaskSnapshot> tasks,
  ) {
    if (tasks.isEmpty) {
      return _tabIndex == 0
          ? _EmptyDownloads(store: store)
          : const _EmptyStopped();
    }
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(20.w, 14.h, 20.w, 24.h),
      itemCount: tasks.length,
      separatorBuilder: (_, _) => SizedBox(height: 14.h),
      itemBuilder: (context, index) {
        var task = tasks[index];
        return _DownloadTaskCard(
          task: task,
          busy: store.isTaskBusy(task.id),
          elapsedSeconds: store.downloadElapsedSeconds(task.id),
          selectionMode: _selecting,
          selected: _selectedIds.contains(task.id),
          onSelect: () => _toggleSelect(task.id),
          onAction: (action) async {
            try {
              await action(ref.read(btDownloadStoreProvider));
            } catch (error) {
              if (context.mounted) {
                await BtInfobar.error(context, error.toString());
              }
            }
          },
        );
      },
    );
  }
}

class _PageTitle extends StatelessWidget {
  const _PageTitle({required this.activeCount, required this.stoppedCount});

  final int activeCount;
  final int stoppedCount;

  @override
  Widget build(BuildContext context) {
    var total = activeCount + stoppedCount;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 38.r,
          height: 38.r,
          decoration: BoxDecoration(
            color: FluentTheme.of(context).accentColor.withValues(alpha: 0.14),
            borderRadius: BTRadius.mediumBR,
          ),
          child: Icon(
            FluentIcons.cloud_download,
            size: 19.sp,
            color: FluentTheme.of(context).accentColor,
          ),
        ),
        SizedBox(width: 12.w),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('下载管理', style: BTTypography.titleLarge(context)),
            Text(
              total == 0
                  ? '管理 BT 下载任务'
                  : '进行中 $activeCount · 已停止 $stoppedCount',
              style: BTTypography.caption(context),
            ),
          ],
        ),
      ],
    );
  }
}

class _EngineStatus extends StatelessWidget {
  const _EngineStatus({required this.state, this.onEnable});

  final BtEngineClientState state;
  final VoidCallback? onEnable;

  @override
  Widget build(BuildContext context) {
    var (label, color) = switch (state) {
      BtEngineClientState.ready => ('引擎已连接', BTColors.successLight(context)),
      BtEngineClientState.starting => ('引擎启动中', BTColors.warningLight(context)),
      BtEngineClientState.stopping => ('引擎关闭中', BTColors.warningLight(context)),
      BtEngineClientState.failed => ('引擎异常', BTColors.errorLight(context)),
      BtEngineClientState.stopped => ('引擎未开启', BTColors.textTertiary(context)),
    };
    var tappable =
        state == BtEngineClientState.stopped ||
        state == BtEngineClientState.failed;
    var chip = Container(
      padding: EdgeInsets.symmetric(horizontal: 11.w, vertical: 7.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BTRadius.roundBR,
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (state == BtEngineClientState.starting ||
              state == BtEngineClientState.stopping)
            SizedBox.square(
              dimension: 7.r,
              child: ProgressRing(strokeWidth: 2),
            )
          else
            Container(
              width: 7.r,
              height: 7.r,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.35),
                    blurRadius: 5,
                  ),
                ],
              ),
            ),
          SizedBox(width: 7.w),
          Text(
            tappable ? '$label · 点击开启' : label,
            style: BTTypography.caption(context).copyWith(color: color),
          ),
        ],
      ),
    );
    if (!tappable) return chip;
    return Tooltip(
      message: state == BtEngineClientState.failed
          ? '点击重新开启下载引擎'
          : '点击开启下载引擎',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(onTap: onEnable, child: chip),
      ),
    );
  }
}

class _TotalRates extends StatelessWidget {
  const _TotalRates({required this.downloadRate, required this.uploadRate});

  final int downloadRate;
  final int uploadRate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: BTColors.surfaceSecondary(context),
        borderRadius: BTRadius.mediumBR,
        border: Border.all(color: BTColors.divider(context)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _RateItem(
            icon: FluentIcons.download,
            color: FluentTheme.of(context).accentColor,
            value: '${BTFileTool.formatSize(downloadRate)}/s',
          ),
          Container(width: 1, height: 20.h, color: BTColors.divider(context)),
          _RateItem(
            icon: FluentIcons.upload,
            color: BTColors.successLight(context),
            value: '${BTFileTool.formatSize(uploadRate)}/s',
          ),
        ],
      ),
    );
  }
}

class _RateItem extends StatelessWidget {
  const _RateItem({
    required this.icon,
    required this.color,
    required this.value,
  });

  final IconData icon;
  final Color color;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13.sp, color: color),
          SizedBox(width: 6.w),
          Text(
            value,
            style: BTTypography.caption(
              context,
            ).copyWith(color: BTColors.textPrimary(context)),
          ),
        ],
      ),
    );
  }
}

class _EmptyDownloads extends StatelessWidget {
  const _EmptyDownloads({required this.store});

  final BtDownloadStore store;

  @override
  Widget build(BuildContext context) {
    var failed = store.engineState == BtEngineClientState.failed;
    var color = failed
        ? BTColors.errorLight(context)
        : FluentTheme.of(context).accentColor;
    return Center(
      child: BTCard(
        useAcrylic: false,
        useReveal: false,
        shadowLevel: BTShadowLevel.subtle,
        padding: EdgeInsets.symmetric(horizontal: 52.w, vertical: 42.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72.r,
              height: 72.r,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                failed ? FluentIcons.error : FluentIcons.cloud_download,
                size: 32.sp,
                color: color,
              ),
            ),
            SizedBox(height: 18.h),
            Text(
              failed ? '下载引擎暂不可用' : '暂无下载任务',
              style: BTTypography.subtitle(context),
            ),
            SizedBox(height: 6.h),
            Text(
              failed
                  ? '请检查引擎状态后重试'
                  : store.engineState == BtEngineClientState.stopped
                  ? '下载引擎未开启，点击右上角引擎状态开启'
                  : '从 RSS 条目添加任务后会显示在这里',
              style: BTTypography.body(
                context,
              ).copyWith(color: BTColors.textSecondary(context)),
            ),
            if (store.lastError != null) ...[
              SizedBox(height: 12.h),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Text(
                  store.lastError!,
                  textAlign: TextAlign.center,
                  style: BTTypography.caption(context).copyWith(color: color),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyStopped extends StatelessWidget {
  const _EmptyStopped();

  @override
  Widget build(BuildContext context) {
    var color = BTColors.textTertiary(context);
    return Center(
      child: BTCard(
        useAcrylic: false,
        useReveal: false,
        shadowLevel: BTShadowLevel.subtle,
        padding: EdgeInsets.symmetric(horizontal: 52.w, vertical: 42.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72.r,
              height: 72.r,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(FluentIcons.check_mark, size: 32.sp, color: color),
            ),
            SizedBox(height: 18.h),
            Text('暂无已停止任务', style: BTTypography.subtitle(context)),
            SizedBox(height: 6.h),
            Text(
              '下载出错或完成做种的任务会显示在这里',
              style: BTTypography.body(
                context,
              ).copyWith(color: BTColors.textSecondary(context)),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectionBar extends StatelessWidget {
  const _SelectionBar({
    required this.count,
    required this.onSelectAll,
    required this.onClear,
    required this.onDelete,
    required this.onCancel,
  });

  final int count;
  final VoidCallback? onSelectAll;
  final VoidCallback? onClear;
  final Future<void> Function()? onDelete;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    var accent = FluentTheme.of(context).accentColor;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: BTColors.surfaceSecondary(context),
        borderRadius: BTRadius.mediumBR,
        border: Border.all(color: BTColors.divider(context)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 8.w),
            child: Text(
              '$count',
              style: BTTypography.caption(context).copyWith(
                color: count == 0 ? BTColors.textSecondary(context) : accent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Tooltip(
            message: '全选',
            child: IconButton(
              icon: Icon(
                FluentIcons.select_all,
                size: 16,
                color: onSelectAll == null
                    ? BTColors.textTertiary(context)
                    : null,
              ),
              onPressed: onSelectAll,
            ),
          ),
          Tooltip(
            message: '清除选择',
            child: IconButton(
              icon: Icon(
                FluentIcons.clear_selection,
                size: 16,
                color: onClear == null
                    ? BTColors.textTertiary(context)
                    : null,
              ),
              onPressed: onClear,
            ),
          ),
          Tooltip(
            message: '删除所选',
            child: IconButton(
              icon: Icon(
                FluentIcons.delete,
                size: 16,
                color: onDelete == null
                    ? BTColors.textTertiary(context)
                    : BTColors.errorLight(context),
              ),
              onPressed: onDelete,
            ),
          ),
          Tooltip(
            message: '退出选择',
            child: IconButton(
              icon: const Icon(FluentIcons.cancel, size: 16),
              onPressed: onCancel,
            ),
          ),
        ],
      ),
    );
  }
}

class _DownloadTaskCard extends StatelessWidget {
  const _DownloadTaskCard({
    required this.task,
    required this.busy,
    required this.elapsedSeconds,
    required this.onAction,
    this.selectionMode = false,
    this.selected = false,
    this.onSelect,
  });

  final BtTaskSnapshot task;
  final bool busy;
  final int elapsedSeconds;
  final bool selectionMode;
  final bool selected;
  final VoidCallback? onSelect;
  final Future<void> Function(
    Future<void> Function(BtDownloadStore store) action,
  )
  onAction;

  @override
  Widget build(BuildContext context) {
    var progress = (task.progress * 100).clamp(0, 100).toDouble();
    var title = task.displayName.isNotEmpty
        ? task.displayName
        : task.displayInfoHash ?? task.id;
    var stateColor = _taskStateColor(context, task.state);
    var accentColor = FluentTheme.of(context).accentColor;
    return BTCard(
      padding: EdgeInsets.zero,
      useAcrylic: false,
      useReveal: true,
      shadowLevel: BTShadowLevel.subtle,
      borderColor: selected ? accentColor : stateColor.withValues(alpha: 0.18),
      backgroundColor: selected ? accentColor.withValues(alpha: 0.06) : null,
      onTap: selectionMode ? onSelect : null,
      child: ClipRRect(
        borderRadius: BTRadius.largeBR,
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 4.w,
              child: ColoredBox(color: stateColor),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(20.w, 15.h, 14.w, 14.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (selectionMode) ...[
                        Checkbox(
                          checked: selected,
                          onChanged: (_) => onSelect?.call(),
                        ),
                        SizedBox(width: 4.w),
                      ],
                      Container(
                        width: 36.r,
                        height: 36.r,
                        decoration: BoxDecoration(
                          color: stateColor.withValues(alpha: 0.11),
                          borderRadius: BTRadius.mediumBR,
                        ),
                        child: Icon(
                          _taskStateIcon(task.state),
                          size: 17.sp,
                          color: stateColor,
                        ),
                      ),
                      SizedBox(width: 11.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: BTTypography.bodyStrong(context),
                            ),
                            SizedBox(height: 4.h),
                            Row(
                              children: [
                                Icon(
                                  FluentIcons.folder_open,
                                  size: 12.sp,
                                  color: BTColors.textTertiary(context),
                                ),
                                SizedBox(width: 5.w),
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
                      SizedBox(width: 12.w),
                      _TaskStateBadge(state: task.state, color: stateColor),
                      if (!selectionMode) ...[
                        SizedBox(width: 8.w),
                        _TaskActions(
                          task: task,
                          busy: busy,
                          onAction: onAction,
                        ),
                      ],
                    ],
                  ),
                  SizedBox(height: 14.h),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BTRadius.roundBR,
                          child: ProgressBar(
                            value: progress,
                            strokeWidth: 6.h,
                            activeColor: stateColor,
                            backgroundColor: stateColor.withValues(alpha: 0.1),
                          ),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      SizedBox(
                        width: 50.w,
                        child: Text(
                          '${progress.toStringAsFixed(1)}%',
                          textAlign: TextAlign.right,
                          style: BTTypography.bodyStrong(
                            context,
                          ).copyWith(color: stateColor),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 13.h),
                  Wrap(
                    spacing: 8.w,
                    runSpacing: 8.h,
                    children: [
                      _TaskMetric(
                        icon: FluentIcons.database,
                        label: '已下载',
                        value:
                            '${BTFileTool.formatSize(task.downloadedBytes)} / ${BTFileTool.formatSize(task.totalBytes)}',
                        color: stateColor,
                      ),
                      _TaskMetric(
                        icon: FluentIcons.download,
                        label: '下载',
                        value: '${BTFileTool.formatSize(task.downloadRate)}/s',
                        color: FluentTheme.of(context).accentColor,
                      ),
                      _TaskMetric(
                        icon: FluentIcons.upload,
                        label: '上传',
                        value: '${BTFileTool.formatSize(task.uploadRate)}/s',
                        color: BTColors.successLight(context),
                      ),
                      _TaskMetric(
                        icon: FluentIcons.people,
                        label: '连接',
                        value: '${task.peers} Peer · ${task.seeds} Seed',
                        color: BTColors.info,
                      ),
                      if (task.state == 'downloading' &&
                          task.downloadRate > 0 &&
                          task.totalBytes > task.downloadedBytes)
                        _TaskMetric(
                          icon: FluentIcons.timer,
                          label: '预计耗时',
                          value: _etaLabel(task),
                          color: BTColors.warningLight(context),
                        ),
                      if (elapsedSeconds > 0)
                        _TaskMetric(
                          icon: FluentIcons.history,
                          label: '总耗时',
                          value: _formatDuration(elapsedSeconds),
                          color: BTColors.info,
                        ),
                      if (task.state == 'seeding' || task.uploadedBytes > 0)
                        _TaskMetric(
                          icon: FluentIcons.share,
                          label: '做种',
                          value:
                              '分享率 ${task.shareRatio.toStringAsFixed(2)} · '
                              '${_formatDuration(task.seedingSeconds)}',
                          color: BTColors.successLight(context),
                        ),
                      if (task.seedStopReason != null)
                        _TaskMetric(
                          icon: FluentIcons.check_mark,
                          label: '停止',
                          value: _seedStopReasonLabel(task.seedStopReason!),
                          color: BTColors.textSecondary(context),
                        ),
                    ],
                  ),
                  if (task.lastError != null) ...[
                    SizedBox(height: 12.h),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(
                        horizontal: 11.w,
                        vertical: 9.h,
                      ),
                      decoration: BoxDecoration(
                        color: BTColors.errorLight(
                          context,
                        ).withValues(alpha: 0.08),
                        borderRadius: BTRadius.smallBR,
                        border: Border.all(
                          color: BTColors.errorLight(
                            context,
                          ).withValues(alpha: 0.18),
                        ),
                      ),
                      child: Text(
                        '${task.lastError!.code}: ${task.lastError!.message}',
                        style: BTTypography.caption(
                          context,
                        ).copyWith(color: BTColors.errorLight(context)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskStateBadge extends StatelessWidget {
  const _TaskStateBadge({required this.state, required this.color});

  final String state;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 5.h),
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

class _TaskMetric extends StatelessWidget {
  const _TaskMetric({
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
    var chip = Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 7.h),
      decoration: BoxDecoration(
        color: BTColors.surfaceSecondary(context).withValues(alpha: 0.7),
        borderRadius: BTRadius.smallBR,
        border: Border.all(color: BTColors.divider(context)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12.sp, color: color),
          SizedBox(width: 6.w),
          Text(
            value,
            style: BTTypography.caption(context).copyWith(
              color: BTColors.textPrimary(context),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
    if (label.isEmpty) return chip;
    return Tooltip(message: label, child: chip);
  }
}

class _TaskActions extends StatelessWidget {
  const _TaskActions({
    required this.task,
    required this.busy,
    required this.onAction,
  });

  final BtTaskSnapshot task;
  final bool busy;
  final Future<void> Function(
    Future<void> Function(BtDownloadStore store) action,
  )
  onAction;

  @override
  Widget build(BuildContext context) {
    if (busy) {
      return const SizedBox.square(
        dimension: 28,
        child: Padding(
          padding: EdgeInsets.all(5),
          child: ProgressRing(strokeWidth: 2),
        ),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _button(
          context,
          FluentIcons.info,
          '任务详情',
          () async {
            await showBTDrawer(
              context: context,
              width: 760,
              child: BTDrawer(
                title: '任务详情',
                child: DownloadTaskDetails(taskId: task.id, initialTask: task),
              ),
            );
          },
          color: FluentTheme.of(context).accentColor,
          emphasized: true,
        ),
        if ({
          'metadata',
          'checking',
          'queued',
          'downloading',
          'seeding',
        }.contains(task.state))
          _button(
            context,
            FluentIcons.pause,
            '暂停',
            () => onAction((store) => store.pause(task.id)),
          ),
        if (task.state == 'paused')
          _button(
            context,
            FluentIcons.play,
            '继续',
            () => onAction((store) => store.resume(task.id)),
            color: BTColors.successLight(context),
          ),
        if (task.state == 'error')
          _button(
            context,
            FluentIcons.refresh,
            '重试',
            () => onAction((store) => store.retry(task.id)),
          ),
        _button(
          context,
          FluentIcons.processing,
          '重新校验',
          () => onAction((store) => store.recheck(task.id)),
        ),
        _button(
          context,
          FluentIcons.folder_open,
          '打开目录',
          () async => BTFileTool().openDir(task.savePath),
        ),
        _button(
          context,
          FluentIcons.delete,
          '移除任务 (长按直接删除)',
          () async {
            var confirmed = await showConfirm(
              context,
              title: '移除下载任务？',
              content: '任务将从列表移除，已经下载的数据会保留。',
            );
            if (confirmed) await onAction((store) => store.remove(task.id));
          },
          onLongPress: () => _quickRemove(context),
          color: BTColors.errorLight(context),
        ),
      ],
    );
  }

  Future<void> _quickRemove(BuildContext context) async {
    var downloading = task.state != 'seeding' && task.state != 'completed';
    if (downloading) {
      var confirmed = await showConfirm(
        context,
        title: '删除下载任务？',
        content: '任务仍在下载，将停止下载与上传，已下载的数据会保留。',
      );
      if (!confirmed) return;
    }
    await onAction((store) async {
      var active =
          task.state == 'seeding' ||
          {
            'metadata',
            'checking',
            'queued',
            'downloading',
          }.contains(task.state);
      if (active) {
        try {
          await store.pause(task.id);
        } catch (_) {
          // 暂停失败不阻塞删除
        }
      }
      await store.remove(task.id);
    });
  }

  Widget _button(
    BuildContext context,
    IconData icon,
    String message,
    Future<void> Function() action, {
    Color? color,
    bool emphasized = false,
    Future<void> Function()? onLongPress,
  }) {
    var foreground = color ?? BTColors.textSecondary(context);
    return Padding(
      padding: EdgeInsets.only(left: 3.w),
      child: Tooltip(
        message: message,
        child: Container(
          width: 30.r,
          height: 30.r,
          decoration: BoxDecoration(
            color: emphasized
                ? foreground.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BTRadius.smallBR,
          ),
          child: IconButton(
            icon: Icon(icon, size: 15.sp, color: foreground),
            onPressed: action,
            onLongPress: onLongPress,
          ),
        ),
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

String _formatDuration(int seconds) {
  var duration = Duration(seconds: seconds);
  var hours = duration.inHours;
  var minutes = duration.inMinutes.remainder(60);
  var secs = duration.inSeconds.remainder(60);
  if (hours > 0) return '$hours 小时 $minutes 分钟';
  if (minutes > 0) return '$minutes 分钟 $secs 秒';
  return '$secs 秒';
}

String _etaLabel(BtTaskSnapshot task) {
  if (task.downloadRate <= 0 || task.totalBytes <= task.downloadedBytes) {
    return '—';
  }
  var seconds =
      ((task.totalBytes - task.downloadedBytes) / task.downloadRate).ceil();
  return _formatDuration(seconds);
}

String _seedStopReasonLabel(String reason) {
  return switch (reason) {
    'disabled' => '未启用做种',
    'ratio' => '达到分享率',
    'time' => '达到时间限制',
    _ => reason,
  };
}
