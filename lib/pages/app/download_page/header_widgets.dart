part of '../download_page.dart';

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
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: FluentTheme.of(context).accentColor.withValues(alpha: 0.14),
            borderRadius: BTRadius.mediumBR,
          ),
          child: Icon(
            FluentIcons.cloud_download,
            size: 19,
            color: FluentTheme.of(context).accentColor,
          ),
        ),
        SizedBox(width: 12),
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
      padding: EdgeInsets.symmetric(horizontal: 11, vertical: 7),
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
            SizedBox.square(dimension: 7, child: ProgressRing(strokeWidth: 2))
          else
            Container(
              width: 7,
              height: 7,
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
          SizedBox(width: 7),
          Text(
            tappable ? '$label · 点击开启' : label,
            style: BTTypography.caption(context).copyWith(color: color),
          ),
        ],
      ),
    );
    if (!tappable) return chip;
    return Tooltip(
      message: state == BtEngineClientState.failed ? '点击重新开启下载引擎' : '点击开启下载引擎',
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
      padding: EdgeInsets.symmetric(horizontal: 5, vertical: 4),
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
          Container(width: 1, height: 20, color: BTColors.divider(context)),
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
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          SizedBox(width: 6),
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
      padding: EdgeInsets.symmetric(horizontal: 5, vertical: 4),
      decoration: BoxDecoration(
        color: BTColors.surfaceSecondary(context),
        borderRadius: BTRadius.mediumBR,
        border: Border.all(color: BTColors.divider(context)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
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
                color: onClear == null ? BTColors.textTertiary(context) : null,
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
