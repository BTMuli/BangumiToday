import 'dart:async';
import 'dart:math';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;

import '../../core/services/bt_engine_client.dart';
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
    return TabView(
      currentIndex: _tabIndex,
      onChanged: (index) => setState(() => _tabIndex = index),
      closeButtonVisibility: CloseButtonVisibilityMode.never,
      tabWidthBehavior: TabWidthBehavior.equal,
      tabs: [
        Tab(
          icon: const Icon(FluentIcons.info, size: 16),
          text: const Text('信息'),
          body: _OverviewTab(task: task, details: _details!),
        ),
        Tab(
          icon: const Icon(FluentIcons.processing, size: 16),
          text: const Text('进度'),
          body: _ProgressTab(task: task, details: _details!),
        ),
        Tab(
          icon: const Icon(FluentIcons.people, size: 16),
          text: Text('Peer ${_details!.peers.length}'),
          body: _PeersTab(details: _details!),
        ),
        Tab(
          icon: const Icon(FluentIcons.folder, size: 16),
          text: Text('文件 ${_details!.files.length}'),
          body: _FilesTab(details: _details!),
        ),
      ],
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
          const Icon(FluentIcons.error, size: 36),
          const SizedBox(height: 12),
          Text(error?.toString() ?? '无法读取任务详情'),
          const SizedBox(height: 12),
          Button(onPressed: onRetry, child: const Text('重试')),
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
    var title = task.displayName.isEmpty
        ? task.infoHash ?? task.id
        : task.displayName;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(title, style: FluentTheme.of(context).typography.subtitle),
        const SizedBox(height: 24),
        _DetailRow(label: '任务状态', value: _stateLabel(task.state)),
        _DetailRow(label: '存储路径', value: task.savePath),
        _DetailRow(label: 'Info Hash', value: task.infoHash ?? '等待元数据'),
        _DetailRow(
          label: '资源大小',
          value: BTFileTool.formatSize(task.totalBytes),
        ),
        _DetailRow(label: '来源类型', value: task.sourceKind),
        _DetailRow(label: '隐私种子', value: task.isPrivate ? '是' : '否'),
        const Divider(),
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
              '分享率 ${task.seedRatioLimit.toStringAsFixed(1)} / '
              '${task.seedTimeLimitMinutes} 分钟',
        ),
        if (task.lastError != null)
          InfoBar(
            title: Text(task.lastError!.code),
            content: Text(task.lastError!.message),
            severity: InfoBarSeverity.error,
          ),
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
      padding: const EdgeInsets.all(24),
      children: [
        _PieceMap(completedPieces: details.completedPieces),
        const SizedBox(height: 24),
        Row(
          children: [
            const Text('任务进度'),
            const SizedBox(width: 16),
            Expanded(child: ProgressBar(value: percent)),
            const SizedBox(width: 12),
            Text('${percent.toStringAsFixed(1)}%'),
          ],
        ),
        const SizedBox(height: 20),
        _DetailRow(
          label: '已下载',
          value:
              '${BTFileTool.formatSize(task.downloadedBytes)} / '
              '${BTFileTool.formatSize(task.totalBytes)}',
        ),
        _DetailRow(
          label: '下载速度',
          value: '${BTFileTool.formatSize(task.downloadRate)}/s',
        ),
        _DetailRow(
          label: '上传速度',
          value: '${BTFileTool.formatSize(task.uploadRate)}/s',
        ),
        _DetailRow(
          label: '已上传',
          value: BTFileTool.formatSize(task.uploadedBytes),
        ),
        _DetailRow(label: '连接数', value: '${task.peers}'),
        _DetailRow(label: '种子数', value: '${task.seeds}'),
        _DetailRow(label: '分享率', value: task.shareRatio.toStringAsFixed(2)),
        _DetailRow(label: '已做种', value: _durationLabel(task.seedingSeconds)),
      ],
    );
  }
}

class _PieceMap extends StatelessWidget {
  const _PieceMap({required this.completedPieces});

  final String completedPieces;

  @override
  Widget build(BuildContext context) {
    if (completedPieces.isEmpty) {
      return const SizedBox(height: 120, child: Center(child: Text('等待分片信息')));
    }
    const maxCells = 480;
    var groupSize = max(1, (completedPieces.length / maxCells).ceil());
    var cellCount = (completedPieces.length / groupSize).ceil();
    var accent = FluentTheme.of(context).accentColor;
    var inactive = FluentTheme.of(context).resources.cardStrokeColorDefault;
    return LayoutBuilder(
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
            return Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: Color.lerp(inactive, accent, ratio),
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        );
      },
    );
  }
}

class _PeersTab extends StatelessWidget {
  const _PeersTab({required this.details});

  final BtTaskDetails details;

  @override
  Widget build(BuildContext context) {
    if (details.peers.isEmpty) return const Center(child: Text('暂无已连接 Peer'));
    return Column(
      children: [
        const _TableHeader(
          columns: ['地址', '客户端', '进度', '↓', '↑'],
          flexes: [3, 3, 1, 2, 2],
        ),
        Expanded(
          child: ListView.separated(
            itemCount: details.peers.length,
            separatorBuilder: (_, _) => const Divider(size: 1),
            itemBuilder: (context, index) {
              var peer = details.peers[index];
              return _TableRow(
                columns: [
                  peer.endpoint,
                  peer.client,
                  '${(peer.progress * 100).toStringAsFixed(0)}%',
                  '${BTFileTool.formatSize(peer.downloadRate)}/s',
                  '${BTFileTool.formatSize(peer.uploadRate)}/s',
                ],
                flexes: const [3, 3, 1, 2, 2],
              );
            },
          ),
        ),
        if (details.peersTruncated)
          const Padding(
            padding: EdgeInsets.all(8),
            child: Text('Peer 较多，仅显示前 500 个'),
          ),
      ],
    );
  }
}

class _FilesTab extends StatelessWidget {
  const _FilesTab({required this.details});

  final BtTaskDetails details;

  @override
  Widget build(BuildContext context) {
    if (details.files.isEmpty) return const Center(child: Text('等待文件信息'));
    return Column(
      children: [
        const _TableHeader(
          columns: ['文件名', '扩展名', '进度', '已完成', '大小'],
          flexes: [5, 1, 1, 2, 2],
        ),
        Expanded(
          child: ListView.separated(
            itemCount: details.files.length,
            separatorBuilder: (_, _) => const Divider(size: 1),
            itemBuilder: (context, index) {
              var file = details.files[index];
              var extension = path.extension(file.path);
              return _TableRow(
                columns: [
                  file.path,
                  extension.isEmpty ? '—' : extension.substring(1),
                  '${(file.progress * 100).toStringAsFixed(1)}%',
                  BTFileTool.formatSize(file.completedBytes),
                  BTFileTool.formatSize(file.size),
                ],
                flexes: const [5, 1, 1, 2, 2],
              );
            },
          ),
        ),
        if (details.filesTruncated)
          const Padding(
            padding: EdgeInsets.all(8),
            child: Text('文件较多，仅显示前 2000 个'),
          ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 112,
            child: Text(
              label,
              style: TextStyle(
                color: FluentTheme.of(context).resources.textFillColorSecondary,
              ),
            ),
          ),
          Expanded(child: SelectableText(value)),
        ],
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      color: FluentTheme.of(context).resources.subtleFillColorSecondary,
      child: Row(
        children: List.generate(
          columns.length,
          (index) => Expanded(
            flex: flexes[index],
            child: Text(
              columns[index],
              style: FluentTheme.of(context).typography.bodyStrong,
            ),
          ),
        ),
      ),
    );
  }
}

class _TableRow extends StatelessWidget {
  const _TableRow({required this.columns, required this.flexes});

  final List<String> columns;
  final List<int> flexes;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: List.generate(
          columns.length,
          (index) => Expanded(
            flex: flexes[index],
            child: Text(
              columns[index],
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }
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

String _durationLabel(int seconds) {
  var duration = Duration(seconds: seconds);
  if (duration.inHours > 0) {
    return '${duration.inHours} 小时 '
        '${duration.inMinutes.remainder(60)} 分钟';
  }
  return '${duration.inMinutes} 分钟 ${duration.inSeconds.remainder(60)} 秒';
}
