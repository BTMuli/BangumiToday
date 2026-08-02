import 'dart:async';
import 'dart:math';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:path/path.dart' as path;

import '../../core/services/bt_engine_client.dart';
import '../../core/theme/bt_theme.dart';
import '../../store/bt_download_store.dart';
import '../../tools/file_tool.dart';

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
  Object? _error;
  Timer? _refreshTimer;
  var _loading = true;
  var _tabIndex = 0;

  @override
  void initState() {
    super.initState();
    Future.microtask(_refresh);
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _refresh(silent: true),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _refresh({bool silent = false}) async {
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
          Expanded(
            child: TabView(
              currentIndex: _tabIndex,
              onChanged: (index) => setState(() => _tabIndex = index),
              closeButtonVisibility: CloseButtonVisibilityMode.never,
              tabWidthBehavior: TabWidthBehavior.equal,
              tabs: [
                Tab(
                  icon: const Icon(FluentIcons.info, size: 15),
                  text: const Text('信息'),
                  body: _OverviewTab(task: task, details: _details!),
                ),
                Tab(
                  icon: const Icon(FluentIcons.processing, size: 15),
                  text: const Text('进度'),
                  body: _ProgressTab(task: task, details: _details!),
                ),
                Tab(
                  icon: const Icon(FluentIcons.people, size: 15),
                  text: Text('Peer ${_details!.peers.length}'),
                  body: _PeersTab(details: _details!),
                ),
                Tab(
                  icon: const Icon(FluentIcons.folder, size: 15),
                  text: Text('文件 ${_details!.files.length}'),
                  body: _FilesTab(details: _details!),
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
        ? task.infoHash ?? task.id
        : task.displayName;
    var color = _taskStateColor(context, task.state);
    var progress = (task.progress * 100).clamp(0, 100).toDouble();
    return Container(
      padding: EdgeInsets.fromLTRB(22.w, 18.h, 22.w, 16.h),
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
                width: 44.r,
                height: 44.r,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BTRadius.largeBR,
                ),
                child: Icon(
                  _taskStateIcon(task.state),
                  size: 21.sp,
                  color: color,
                ),
              ),
              SizedBox(width: 13.w),
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
                    SizedBox(height: 5.h),
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
              SizedBox(width: 10.w),
              _StateBadge(state: task.state, color: color),
            ],
          ),
          SizedBox(height: 16.h),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BTRadius.roundBR,
                  child: ProgressBar(
                    value: progress,
                    strokeWidth: 7.h,
                    activeColor: color,
                    backgroundColor: color.withValues(alpha: 0.1),
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Text(
                '${progress.toStringAsFixed(1)}%',
                style: BTTypography.bodyStrong(context).copyWith(color: color),
              ),
            ],
          ),
          SizedBox(height: 14.h),
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
              SizedBox(width: 8.w),
              Expanded(
                child: _HeroMetric(
                  icon: FluentIcons.upload,
                  label: '上传速度',
                  value: '${BTFileTool.formatSize(task.uploadRate)}/s',
                  color: BTColors.successLight(context),
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: _HeroMetric(
                  icon: FluentIcons.people,
                  label: '连接',
                  value: '${task.peers} Peer · ${task.seeds} Seed',
                  color: BTColors.info,
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
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 9.h),
      decoration: BoxDecoration(
        color: BTColors.surfaceSecondary(context).withValues(alpha: 0.72),
        borderRadius: BTRadius.mediumBR,
        border: Border.all(color: BTColors.divider(context)),
      ),
      child: Row(
        children: [
          Container(
            width: 27.r,
            height: 27.r,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BTRadius.smallBR,
            ),
            child: Icon(icon, size: 13.sp, color: color),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: BTTypography.caption(context)),
                SizedBox(height: 2.h),
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
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
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
            width: 64.r,
            height: 64.r,
            decoration: BoxDecoration(
              color: BTColors.errorLight(context).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              FluentIcons.error,
              size: 28.sp,
              color: BTColors.errorLight(context),
            ),
          ),
          SizedBox(height: 14.h),
          Text('无法读取任务详情', style: BTTypography.subtitle(context)),
          SizedBox(height: 5.h),
          Text(
            error?.toString() ?? '未知错误',
            textAlign: TextAlign.center,
            style: BTTypography.caption(context),
          ),
          SizedBox(height: 14.h),
          Button(onPressed: onRetry, child: const Text('重新加载')),
        ],
      ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({required this.task, required this.details});

  final BtTaskSnapshot task;
  final BtTaskDetails details;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.all(18.w),
      children: [
        _SectionCard(
          icon: FluentIcons.info,
          title: '基本信息',
          child: Column(
            children: [
              _DetailRow(label: '任务状态', value: _stateLabel(task.state)),
              _DetailRow(label: '存储路径', value: task.savePath),
              _DetailRow(label: 'Info Hash', value: task.infoHash ?? '等待元数据'),
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
        SizedBox(height: 12.h),
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
          SizedBox(height: 12.h),
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

class _ProgressTab extends StatelessWidget {
  const _ProgressTab({required this.task, required this.details});

  final BtTaskSnapshot task;
  final BtTaskDetails details;

  @override
  Widget build(BuildContext context) {
    var percent = (task.progress * 100).clamp(0, 100).toDouble();
    return ListView(
      padding: EdgeInsets.all(18.w),
      children: [
        _SectionCard(
          icon: FluentIcons.grid_view_small,
          title: '分片完成情况',
          trailing: Text(
            '${details.completedPieces.codeUnits.where((value) => value == 49).length} / ${details.pieceCount}',
            style: BTTypography.caption(context),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PieceMap(completedPieces: details.completedPieces),
              SizedBox(height: 12.h),
              Row(
                children: [
                  _LegendDot(
                    color: FluentTheme.of(context).accentColor,
                    label: '已完成',
                  ),
                  SizedBox(width: 16.w),
                  _LegendDot(
                    color: BTColors.surfaceTertiary(context),
                    label: '未完成',
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(height: 12.h),
        _SectionCard(
          icon: FluentIcons.processing,
          title: '传输统计',
          child: Column(
            children: [
              Row(
                children: [
                  Text('总体进度', style: BTTypography.body(context)),
                  const Spacer(),
                  Text(
                    '${percent.toStringAsFixed(1)}%',
                    style: BTTypography.subtitle(
                      context,
                    ).copyWith(color: FluentTheme.of(context).accentColor),
                  ),
                ],
              ),
              SizedBox(height: 9.h),
              ClipRRect(
                borderRadius: BTRadius.roundBR,
                child: ProgressBar(
                  value: percent,
                  strokeWidth: 8.h,
                  backgroundColor: FluentTheme.of(
                    context,
                  ).accentColor.withValues(alpha: 0.1),
                ),
              ),
              SizedBox(height: 14.h),
              LayoutBuilder(
                builder: (context, constraints) {
                  var width = (constraints.maxWidth - 10.w) / 2;
                  return Wrap(
                    spacing: 10.w,
                    runSpacing: 10.h,
                    children: [
                      _TransferMetric(
                        width: width,
                        label: '已下载',
                        value:
                            '${BTFileTool.formatSize(task.downloadedBytes)} / ${BTFileTool.formatSize(task.totalBytes)}',
                        icon: FluentIcons.download,
                        color: FluentTheme.of(context).accentColor,
                      ),
                      _TransferMetric(
                        width: width,
                        label: '已上传',
                        value: BTFileTool.formatSize(task.uploadedBytes),
                        icon: FluentIcons.upload,
                        color: BTColors.successLight(context),
                      ),
                      _TransferMetric(
                        width: width,
                        label: '下载速度',
                        value: '${BTFileTool.formatSize(task.downloadRate)}/s',
                        icon: FluentIcons.download,
                        color: FluentTheme.of(context).accentColor,
                      ),
                      _TransferMetric(
                        width: width,
                        label: '上传速度',
                        value: '${BTFileTool.formatSize(task.uploadRate)}/s',
                        icon: FluentIcons.upload,
                        color: BTColors.successLight(context),
                      ),
                      _TransferMetric(
                        width: width,
                        label: '连接 / 种子',
                        value: '${task.peers} / ${task.seeds}',
                        icon: FluentIcons.people,
                        color: BTColors.info,
                      ),
                      _TransferMetric(
                        width: width,
                        label: '分享率 / 做种',
                        value:
                            '${task.shareRatio.toStringAsFixed(2)} / ${_durationLabel(task.seedingSeconds)}',
                        icon: FluentIcons.upload,
                        color: BTColors.warningLight(context),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
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
            padding: EdgeInsets.symmetric(horizontal: 15.w, vertical: 12.h),
            child: Row(
              children: [
                Container(
                  width: 29.r,
                  height: 29.r,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.1),
                    borderRadius: BTRadius.smallBR,
                  ),
                  child: Icon(icon, size: 14.sp, color: accent),
                ),
                SizedBox(width: 9.w),
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
          Padding(padding: EdgeInsets.all(15.w), child: child),
        ],
      ),
    );
  }
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
      padding: EdgeInsets.all(11.w),
      decoration: BoxDecoration(
        color: BTColors.surfaceSecondary(context).withValues(alpha: 0.62),
        borderRadius: BTRadius.mediumBR,
        border: Border.all(color: BTColors.divider(context)),
      ),
      child: Row(
        children: [
          Container(
            width: 31.r,
            height: 31.r,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BTRadius.smallBR,
            ),
            child: Icon(icon, size: 14.sp, color: color),
          ),
          SizedBox(width: 9.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: BTTypography.caption(context)),
                SizedBox(height: 3.h),
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
        height: 110.h,
        decoration: BoxDecoration(
          color: BTColors.surfaceSecondary(context),
          borderRadius: BTRadius.mediumBR,
        ),
        child: Center(
          child: Text('等待分片信息', style: BTTypography.caption(context)),
        ),
      );
    }
    const maxCells = 480;
    var groupSize = max(1, (completedPieces.length / maxCells).ceil());
    var cellCount = (completedPieces.length / groupSize).ceil();
    var accent = FluentTheme.of(context).accentColor;
    var inactive = BTColors.surfaceTertiary(context);
    return Container(
      padding: EdgeInsets.all(10.w),
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
                  borderRadius: BorderRadius.circular(2.5.r),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8.r,
          height: 8.r,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        SizedBox(width: 6.w),
        Text(label, style: BTTypography.caption(context)),
      ],
    );
  }
}

class _PeersTab extends StatelessWidget {
  const _PeersTab({required this.details});

  final BtTaskDetails details;

  @override
  Widget build(BuildContext context) {
    if (details.peers.isEmpty) {
      return const _DetailEmptyState(
        icon: FluentIcons.people,
        title: '暂无已连接 Peer',
        description: '建立连接后会在这里显示客户端与传输状态',
      );
    }
    return _TableShell(
      footer: details.peersTruncated ? 'Peer 较多，仅显示前 500 个' : null,
      header: const _TableHeader(
        columns: ['地址', '客户端', '进度', '下载', '上传'],
        flexes: [3, 3, 2, 2, 2],
      ),
      itemCount: details.peers.length,
      itemBuilder: (context, index) {
        var peer = details.peers[index];
        var progress = (peer.progress * 100).clamp(0, 100).toDouble();
        return _TableRow(
          flexes: const [3, 3, 2, 2, 2],
          columns: [
            Text(peer.endpoint, maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(peer.client, maxLines: 1, overflow: TextOverflow.ellipsis),
            Padding(
              padding: EdgeInsets.only(right: 12.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${progress.toStringAsFixed(0)}%',
                    style: BTTypography.caption(context),
                  ),
                  SizedBox(height: 4.h),
                  ProgressBar(value: progress, strokeWidth: 4.h),
                ],
              ),
            ),
            _RateText(
              value: peer.downloadRate,
              color: FluentTheme.of(context).accentColor,
            ),
            _RateText(
              value: peer.uploadRate,
              color: BTColors.successLight(context),
            ),
          ],
        );
      },
    );
  }
}

class _FilesTab extends StatelessWidget {
  const _FilesTab({required this.details});

  final BtTaskDetails details;

  @override
  Widget build(BuildContext context) {
    if (details.files.isEmpty) {
      return const _DetailEmptyState(
        icon: FluentIcons.folder,
        title: '等待文件信息',
        description: '元数据就绪后会显示文件列表与独立进度',
      );
    }
    return _TableShell(
      footer: details.filesTruncated ? '文件较多，仅显示前 2000 个' : null,
      header: const _TableHeader(
        columns: ['文件名', '类型', '进度', '已完成', '大小'],
        flexes: [5, 1, 2, 2, 2],
      ),
      itemCount: details.files.length,
      itemBuilder: (context, index) {
        var file = details.files[index];
        var extension = path.extension(file.path);
        var progress = (file.progress * 100).clamp(0, 100).toDouble();
        return _TableRow(
          flexes: const [5, 1, 2, 2, 2],
          columns: [
            Row(
              children: [
                Icon(
                  FluentIcons.document,
                  size: 14.sp,
                  color: FluentTheme.of(context).accentColor,
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    file.path,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            Text(
              extension.isEmpty ? '—' : extension.substring(1).toUpperCase(),
            ),
            Padding(
              padding: EdgeInsets.only(right: 12.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${progress.toStringAsFixed(1)}%',
                    style: BTTypography.caption(context),
                  ),
                  SizedBox(height: 4.h),
                  ProgressBar(value: progress, strokeWidth: 4.h),
                ],
              ),
            ),
            Text(BTFileTool.formatSize(file.completedBytes)),
            Text(BTFileTool.formatSize(file.size)),
          ],
        );
      },
    );
  }
}

class _DetailEmptyState extends StatelessWidget {
  const _DetailEmptyState({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    var accent = FluentTheme.of(context).accentColor;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 62.r,
            height: 62.r,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.09),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 27.sp, color: accent),
          ),
          SizedBox(height: 14.h),
          Text(title, style: BTTypography.subtitle(context)),
          SizedBox(height: 5.h),
          Text(description, style: BTTypography.caption(context)),
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
      padding: EdgeInsets.symmetric(vertical: 10.h),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(bottom: BorderSide(color: BTColors.divider(context))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110.w,
            child: Text(label, style: BTTypography.caption(context)),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: BTTypography.body(context).copyWith(fontSize: 13.sp),
            ),
          ),
        ],
      ),
    );
  }
}

class _TableShell extends StatelessWidget {
  const _TableShell({
    required this.header,
    required this.itemCount,
    required this.itemBuilder,
    this.footer,
  });

  final Widget header;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final String? footer;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(18.w),
      child: Container(
        decoration: BoxDecoration(
          color: BTColors.surfacePrimary(context),
          borderRadius: BTRadius.largeBR,
          border: Border.all(color: BTColors.divider(context)),
          boxShadow: BTTheme.shadow(context, level: BTShadowLevel.subtle),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            header,
            Expanded(
              child: ListView.builder(
                itemCount: itemCount,
                itemBuilder: itemBuilder,
              ),
            ),
            if (footer != null)
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                color: BTColors.surfaceSecondary(context),
                child: Text(
                  footer!,
                  textAlign: TextAlign.center,
                  style: BTTypography.caption(context),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader({required this.columns, required this.flexes});

  final List<String> columns;
  final List<int> flexes;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 13.w, vertical: 11.h),
      color: BTColors.surfaceSecondary(context),
      child: Row(
        children: List.generate(
          columns.length,
          (index) => Expanded(
            flex: flexes[index],
            child: Text(
              columns[index],
              style: BTTypography.caption(
                context,
              ).copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ),
    );
  }
}

class _TableRow extends StatefulWidget {
  const _TableRow({required this.columns, required this.flexes});

  final List<Widget> columns;
  final List<int> flexes;

  @override
  State<_TableRow> createState() => _TableRowState();
}

class _TableRowState extends State<_TableRow> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: BTTheme.animationDurationFast,
        padding: EdgeInsets.symmetric(horizontal: 13.w, vertical: 11.h),
        decoration: BoxDecoration(
          color: _hovered
              ? FluentTheme.of(context).accentColor.withValues(alpha: 0.045)
              : Colors.transparent,
          border: Border(bottom: BorderSide(color: BTColors.divider(context))),
        ),
        child: DefaultTextStyle(
          style: BTTypography.caption(
            context,
          ).copyWith(color: BTColors.textPrimary(context)),
          child: Row(
            children: List.generate(
              widget.columns.length,
              (index) => Expanded(
                flex: widget.flexes[index],
                child: widget.columns[index],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RateText extends StatelessWidget {
  const _RateText({required this.value, required this.color});

  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      '${BTFileTool.formatSize(value)}/s',
      style: BTTypography.caption(context).copyWith(
        color: value > 0 ? color : BTColors.textTertiary(context),
        fontWeight: value > 0 ? FontWeight.w600 : FontWeight.w400,
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
