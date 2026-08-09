part of '../download_page.dart';

class _DownloadTaskCard extends StatelessWidget {
  const _DownloadTaskCard({
    required this.task,
    required this.busy,
    required this.onAction,
    this.selectionMode = false,
    this.selected = false,
    this.onSelect,
  });

  final BtTaskSnapshot task;
  final bool busy;
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
              width: 4,
              child: ColoredBox(color: stateColor),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(20, 15, 14, 14),
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
                        SizedBox(width: 4),
                      ],
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: stateColor.withValues(alpha: 0.11),
                          borderRadius: BTRadius.mediumBR,
                        ),
                        child: Icon(
                          _taskStateIcon(task.state),
                          size: 17,
                          color: stateColor,
                        ),
                      ),
                      SizedBox(width: 11),
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
                            SizedBox(height: 4),
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
                      SizedBox(width: 12),
                      _TaskStateBadge(state: task.state, color: stateColor),
                      if (!selectionMode) ...[
                        SizedBox(width: 8),
                        _TaskActions(
                          task: task,
                          busy: busy,
                          onAction: onAction,
                        ),
                      ],
                    ],
                  ),
                  SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BTRadius.roundBR,
                          child: ProgressBar(
                            value: progress,
                            strokeWidth: 6,
                            activeColor: stateColor,
                            backgroundColor: stateColor.withValues(alpha: 0.1),
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      SizedBox(
                        width: 50,
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
                  SizedBox(height: 13),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
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
                    SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 9,
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
      padding: EdgeInsets.symmetric(horizontal: 9, vertical: 5),
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
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: BTColors.surfaceSecondary(context).withValues(alpha: 0.7),
        borderRadius: BTRadius.smallBR,
        border: Border.all(color: BTColors.divider(context)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          SizedBox(width: 6),
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
      padding: EdgeInsets.only(left: 3),
      child: Tooltip(
        message: message,
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: emphasized
                ? foreground.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BTRadius.smallBR,
          ),
          child: IconButton(
            icon: Icon(icon, size: 15, color: foreground),
            onPressed: action,
            onLongPress: onLongPress,
          ),
        ),
      ),
    );
  }
}
