// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

// Project imports:
import '../../core/services/bt_engine_client.dart';
import '../../store/bt_download_store.dart';
import '../../tools/file_tool.dart';
import '../../ui/bt_dialog.dart';
import '../../ui/bt_infobar.dart';

class DownloadPage extends ConsumerWidget {
  const DownloadPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var store = ref.watch(btDownloadStoreProvider);
    return ScaffoldPage(
      header: PageHeader(
        title: const Text('下载管理'),
        commandBar: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _EngineStatus(state: store.engineState),
            SizedBox(width: 8.w),
            IconButton(
              icon: store.refreshing
                  ? const SizedBox.square(
                      dimension: 16,
                      child: ProgressRing(strokeWidth: 2),
                    )
                  : const Icon(FluentIcons.refresh),
              onPressed: store.refreshing
                  ? null
                  : () async {
                      try {
                        await ref.read(btDownloadStoreProvider).refresh();
                        if (context.mounted) {
                          await BtInfobar.success(context, '下载任务已刷新');
                        }
                      } catch (error) {
                        if (context.mounted) {
                          await BtInfobar.error(context, error.toString());
                        }
                      }
                    },
            ),
          ],
        ),
      ),
      content: _buildContent(context, ref, store),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    BtDownloadStore store,
  ) {
    if (store.tasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              store.engineState == BtEngineClientState.failed
                  ? FluentIcons.error
                  : FluentIcons.cloud_download,
              size: 48,
            ),
            SizedBox(height: 12.h),
            Text(
              store.engineState == BtEngineClientState.failed
                  ? '下载引擎暂不可用'
                  : '暂无下载任务',
              style: FluentTheme.of(context).typography.subtitle,
            ),
            if (store.lastError != null) ...[
              SizedBox(height: 8.h),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Text(
                  store.lastError!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: FluentTheme.of(
                      context,
                    ).resources.textFillColorTertiary,
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      itemCount: store.tasks.length,
      separatorBuilder: (_, _) => SizedBox(height: 12.h),
      itemBuilder: (context, index) {
        var task = store.tasks[index];
        return _DownloadTaskCard(
          task: task,
          busy: store.isTaskBusy(task.id),
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

class _EngineStatus extends StatelessWidget {
  const _EngineStatus({required this.state});

  final BtEngineClientState state;

  @override
  Widget build(BuildContext context) {
    var (label, color) = switch (state) {
      BtEngineClientState.ready => ('引擎已连接', Colors.green),
      BtEngineClientState.starting => ('引擎启动中', Colors.orange),
      BtEngineClientState.stopping => ('引擎关闭中', Colors.orange),
      BtEngineClientState.failed => ('引擎异常', Colors.red),
      BtEngineClientState.stopped => ('引擎未启动', Colors.grey),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label),
      ],
    );
  }
}

class _DownloadTaskCard extends StatelessWidget {
  const _DownloadTaskCard({
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
    var progress = (task.progress * 100).clamp(0, 100).toDouble();
    var title = task.displayName.isNotEmpty
        ? task.displayName
        : task.infoHash ?? task.id;
    return Card(
      child: Padding(
        padding: EdgeInsets.all(12.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: FluentTheme.of(context).typography.bodyStrong,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        task.savePath,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                _TaskActions(task: task, busy: busy, onAction: onAction),
              ],
            ),
            SizedBox(height: 12.h),
            ProgressBar(value: progress),
            SizedBox(height: 8.h),
            Wrap(
              spacing: 16.w,
              runSpacing: 4.h,
              children: [
                Text(
                  '${_stateLabel(task.state)} · '
                  '${progress.toStringAsFixed(1)}%',
                ),
                Text(
                  '${BTFileTool.formatSize(task.downloadedBytes)} / '
                  '${BTFileTool.formatSize(task.totalBytes)}',
                ),
                Text('↓ ${BTFileTool.formatSize(task.downloadRate)}/s'),
                Text('↑ ${BTFileTool.formatSize(task.uploadRate)}/s'),
                Text('Peer ${task.peers} · Seed ${task.seeds}'),
                if (task.state == 'seeding' || task.uploadedBytes > 0)
                  Text(
                    '分享率 ${task.shareRatio.toStringAsFixed(2)} · '
                    '已做种 ${_formatDuration(task.seedingSeconds)}',
                  ),
                if (task.seedStopReason != null)
                  Text('停止原因：${_seedStopReasonLabel(task.seedStopReason!)}'),
              ],
            ),
            if (task.lastError != null) ...[
              SizedBox(height: 8.h),
              Text(
                '${task.lastError!.code}: ${task.lastError!.message}',
                style: TextStyle(color: Colors.red),
              ),
            ],
          ],
        ),
      ),
    );
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
    return hours > 0 ? '$hours 小时 $minutes 分钟' : '$minutes 分钟';
  }

  String _seedStopReasonLabel(String reason) {
    return switch (reason) {
      'disabled' => '未启用做种',
      'ratio' => '达到分享率',
      'time' => '达到时间限制',
      _ => reason,
    };
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
        dimension: 20,
        child: ProgressRing(strokeWidth: 2),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if ({
          'metadata',
          'checking',
          'queued',
          'downloading',
          'seeding',
        }.contains(task.state))
          _button(
            FluentIcons.pause,
            '暂停',
            () => onAction((store) => store.pause(task.id)),
          ),
        if (task.state == 'paused')
          _button(
            FluentIcons.play,
            '继续',
            () => onAction((store) => store.resume(task.id)),
          ),
        if (task.state == 'error')
          _button(
            FluentIcons.refresh,
            '重试',
            () => onAction((store) => store.retry(task.id)),
          ),
        _button(
          FluentIcons.processing,
          '重新校验',
          () => onAction((store) => store.recheck(task.id)),
        ),
        _button(
          FluentIcons.folder_open,
          '打开目录',
          () async => BTFileTool().openDir(task.savePath),
        ),
        _button(FluentIcons.delete, '移除任务', () async {
          var confirmed = await showConfirm(
            context,
            title: '移除下载任务？',
            content: '任务将从列表移除，已经下载的数据会保留。',
          );
          if (confirmed) {
            await onAction((store) => store.remove(task.id));
          }
        }),
      ],
    );
  }

  Widget _button(
    IconData icon,
    String message,
    Future<void> Function() action,
  ) {
    return Tooltip(
      message: message,
      child: IconButton(icon: Icon(icon), onPressed: action),
    );
  }
}
