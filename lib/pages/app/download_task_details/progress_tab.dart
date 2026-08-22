part of '../download_task_details.dart';

class _ProgressTab extends StatelessWidget {
  const _ProgressTab({required this.task, required this.details});

  final BtTaskSnapshot task;
  final BtTaskDetails details;

  @override
  Widget build(BuildContext context) {
    var isHttp = task.sourceKind == 'http';
    return _KeyboardScrollable(
      builder: (context, controller) => ListView(
        controller: controller,
        padding: EdgeInsets.all(18),
        children: [
          _SectionCard(
            icon: FluentIcons.grid_view_small,
            title: '分片完成情况',
            trailing: Text(
              _pieceSummary(details) +
                  _pieceGridNote(details.completedPieces.length),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: BTTypography.caption(context),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PieceMap(completedPieces: details.completedPieces),
                SizedBox(height: 12),
                _PieceLegend(pieceCount: details.completedPieces.length),
                if (isHttp) ...[
                  SizedBox(height: 8),
                  Text(
                    'HTTP 分片按字节区间展示传输进度，不代表内容已经过哈希校验；'
                    '服务器支持时使用多条 Range 连接，不支持时自动降级。',
                    style: BTTypography.caption(context),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(height: 12),
          _SectionCard(
            icon: FluentIcons.processing,
            title: '传输统计',
            child: LayoutBuilder(
              builder: (context, constraints) {
                var width = (constraints.maxWidth - 10) / 2;
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _TransferMetric(
                      width: width,
                      label: '已下载',
                      value:
                          '${BTFileTool.formatSize(task.downloadedBytes)} / ${BTFileTool.formatSize(task.totalBytes)}',
                      icon: FluentIcons.download,
                      color: FluentTheme.of(context).accentColor,
                    ),
                    if (isHttp)
                      _TransferMetric(
                        width: width,
                        label: 'HTTP 连接',
                        value: details.httpConnections > 0
                            ? '${details.httpConnections} 条'
                            : '未连接',
                        icon: FluentIcons.link,
                        color: BTColors.info,
                      ),
                    if (!isHttp) ...[
                      _TransferMetric(
                        width: width,
                        label: '已上传',
                        value: BTFileTool.formatSize(task.uploadedBytes),
                        icon: FluentIcons.upload,
                        color: BTColors.successLight(context),
                      ),
                      _TransferMetric(
                        width: width,
                        label: '已校验',
                        value:
                            '${BTFileTool.formatSize(task.verifiedBytes)} / ${BTFileTool.formatSize(task.totalBytes)}',
                        icon: FluentIcons.check_mark,
                        color: BTColors.info,
                      ),
                      _TransferMetric(
                        width: width,
                        label: '连接',
                        value: '${task.peers} Peer · ${task.seeds} Seed',
                        icon: FluentIcons.people,
                        color: BTColors.info,
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

String _pieceSummary(BtTaskDetails details) {
  var completed = details.completedPieces.codeUnits
      .where((value) => value == 49)
      .length;
  var size = details.pieceLength > 0
      ? ' · ${BTFileTool.formatSize(details.pieceLength)}/片'
      : '';
  return '$completed / ${details.pieceCount}$size';
}

(int groupSize, int cellCount) _pieceGridInfo(int pieceCount) {
  const maxCells = 1200;
  var groupSize = max(1, (pieceCount / maxCells).ceil());
  var cellCount = (pieceCount / groupSize).ceil();
  return (groupSize, cellCount);
}

String _pieceGridNote(int pieceCount) {
  var (groupSize, cellCount) = _pieceGridInfo(pieceCount);
  return groupSize > 1 ? ' · 每格 $groupSize 片 · 共 $cellCount 格' : '';
}

class _TransferMetric extends StatelessWidget {
  const _TransferMetric({
    required this.width,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final double width;
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: BTColors.surfaceSecondary(context).withValues(alpha: 0.62),
        borderRadius: BTRadius.mediumBR,
        border: Border.all(color: BTColors.divider(context)),
      ),
      child: Row(
        children: [
          Container(
            width: 31,
            height: 31,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BTRadius.smallBR,
            ),
            child: Icon(icon, size: 14, color: color),
          ),
          SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: BTTypography.caption(context)),
                SizedBox(height: 3),
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

class _PieceMap extends StatelessWidget {
  const _PieceMap({required this.completedPieces});

  final String completedPieces;

  @override
  Widget build(BuildContext context) {
    if (completedPieces.isEmpty) {
      return Container(
        height: 110,
        decoration: BoxDecoration(
          color: BTColors.surfaceSecondary(context),
          borderRadius: BTRadius.mediumBR,
        ),
        child: Center(
          child: Text('等待分片信息', style: BTTypography.caption(context)),
        ),
      );
    }
    var (groupSize, cellCount) = _pieceGridInfo(completedPieces.length);
    var accent = FluentTheme.of(context).accentColor;
    var inactive = BTColors.surfaceTertiary(context);
    return Container(
      padding: EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: BTColors.surfaceSecondary(context).withValues(alpha: 0.62),
        borderRadius: BTRadius.mediumBR,
        border: Border.all(color: BTColors.divider(context)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          var columns = max(12, (constraints.maxWidth / 15).floor());
          var spacing = 3.0;
          var size = (constraints.maxWidth - (columns - 1) * spacing) / columns;
          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: List.generate(cellCount, (cell) {
              var start = cell * groupSize;
              var end = min(start + groupSize, completedPieces.length);
              var completed = 0;
              for (var index = start; index < end; index++) {
                if (completedPieces.codeUnitAt(index) == 49) completed++;
              }
              var ratio = completed / (end - start);
              return AnimatedContainer(
                duration: BTTheme.animationDurationNormal,
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: Color.lerp(inactive, accent, ratio),
                  borderRadius: BorderRadius.circular(2.5),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}

/// 分片网格图例：左侧未完成、右侧已完成，中央按未完成到已完成的
class _PieceLegend extends StatelessWidget {
  const _PieceLegend({required this.pieceCount});

  final int pieceCount;

  @override
  Widget build(BuildContext context) {
    var accent = FluentTheme.of(context).accentColor;
    var inactive = BTColors.surfaceTertiary(context);
    return Row(
      children: [
        Text('未完成', style: BTTypography.caption(context)),
        SizedBox(width: 4),
        _LegendCells(count: 6, from: inactive, to: accent),
        SizedBox(width: 4),
        Text('已完成', style: BTTypography.caption(context)),
      ],
    );
  }
}

class _LegendCells extends StatelessWidget {
  const _LegendCells({
    required this.count,
    required this.from,
    required this.to,
  });

  final int count;
  final Color from;
  final Color to;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(count, (index) {
        var t = count <= 1 ? 0.0 : index / (count - 1);
        return Padding(
          padding: EdgeInsets.only(left: 3),
          child: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: Color.lerp(from, to, t),
              borderRadius: BorderRadius.circular(2.5),
            ),
          ),
        );
      }),
    );
  }
}
