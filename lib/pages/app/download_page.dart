// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

part 'download_page/empty_states.dart';
part 'download_page/header_widgets.dart';
part 'download_page/task_card.dart';

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
            SizedBox(width: 12),
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
          spacing: 6,
          runSpacing: 6,
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
      padding: EdgeInsets.fromLTRB(20, 14, 20, 24),
      itemCount: tasks.length,
      separatorBuilder: (_, _) => SizedBox(height: 14),
      itemBuilder: (context, index) {
        var task = tasks[index];
        return _DownloadTaskCard(
          task: task,
          busy: store.isTaskBusy(task.id),
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
  var seconds = ((task.totalBytes - task.downloadedBytes) / task.downloadRate)
      .ceil();
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
