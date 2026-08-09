part of '../download_task_details.dart';

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({required this.task, required this.details});

  final BtTaskSnapshot task;
  final BtTaskDetails details;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.all(18),
      children: [
        _SectionCard(
          icon: FluentIcons.info,
          title: '基本信息',
          child: Column(
            children: [
              _DetailRow(label: '任务状态', value: _stateLabel(task.state)),
              _DetailRow(label: '存储路径', value: task.savePath),
              _DetailRow(
                label: 'Info Hash',
                value: task.displayInfoHash ?? '等待元数据',
              ),
              _DetailRow(
                label: '资源大小',
                value: BTFileTool.formatSize(task.totalBytes),
              ),
              _DetailRow(
                label: '来源类型',
                value: _sourceKindLabel(task.sourceKind),
              ),
              _DetailRow(
                label: '隐私种子',
                value: task.isPrivate ? '是' : '否',
                isLast: true,
              ),
            ],
          ),
        ),
        SizedBox(height: 12),
        _SectionCard(
          icon: FluentIcons.processing,
          title: '种子信息',
          child: Column(
            children: [
              _DetailRow(
                label: '分片大小',
                value: details.pieceLength > 0
                    ? BTFileTool.formatSize(details.pieceLength)
                    : '等待元数据',
              ),
              _DetailRow(label: '分片数量', value: '${details.pieceCount}'),
              _DetailRow(label: '文件数量', value: '${details.files.length}'),
              _DetailRow(
                label: '做种策略',
                value:
                    '分享率 ${task.seedRatioLimit.toStringAsFixed(1)} · '
                    '${task.seedTimeLimitMinutes} 分钟',
                isLast: true,
              ),
            ],
          ),
        ),
        if (task.lastError != null) ...[
          SizedBox(height: 12),
          InfoBar(
            title: Text(task.lastError!.code),
            content: Text(task.lastError!.message),
            severity: InfoBarSeverity.error,
          ),
        ],
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.child,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    var accent = FluentTheme.of(context).accentColor;
    return Container(
      decoration: BoxDecoration(
        color: BTColors.surfacePrimary(context),
        borderRadius: BTRadius.largeBR,
        border: Border.all(color: BTColors.divider(context)),
        boxShadow: BTTheme.shadow(context, level: BTShadowLevel.subtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 15, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 29,
                  height: 29,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.1),
                    borderRadius: BTRadius.smallBR,
                  ),
                  child: Icon(icon, size: 14, color: accent),
                ),
                SizedBox(width: 9),
                Expanded(
                  child: Text(title, style: BTTypography.bodyStrong(context)),
                ),
                ?trailing,
              ],
            ),
          ),
          Divider(
            size: 1,
            style: DividerThemeData(
              decoration: BoxDecoration(color: BTColors.divider(context)),
            ),
          ),
          Padding(padding: EdgeInsets.all(15), child: child),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.isLast = false,
  });

  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(bottom: BorderSide(color: BTColors.divider(context))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: BTTypography.caption(context)),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: BTTypography.body(context).copyWith(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
