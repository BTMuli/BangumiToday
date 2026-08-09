part of '../download_task_details.dart';

class _FilesTab extends ConsumerStatefulWidget {
  const _FilesTab({
    required this.files,
    required this.truncated,
    required this.task,
    required this.taskId,
    required this.loading,
    this.error,
    this.onRetry,
  });

  final List<BtTaskFileDetail> files;
  final bool truncated;
  final BtTaskSnapshot task;
  final String taskId;
  final bool loading;
  final String? error;
  final VoidCallback? onRetry;

  @override
  ConsumerState<_FilesTab> createState() => _FilesTabState();
}

class _FilesTabState extends ConsumerState<_FilesTab> {
  late List<BtTaskFileDetail> _files;
  final Set<int> _busyIndices = {};

  @override
  void initState() {
    super.initState();
    _files = List.of(widget.files);
  }

  @override
  void didUpdateWidget(covariant _FilesTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.task.id != widget.task.id ||
        (_busyIndices.isEmpty && !identical(oldWidget.files, widget.files))) {
      _files = List.of(widget.files);
    }
  }

  bool get _canEdit {
    var state = widget.task.state;
    return state != 'completed' && state != 'seeding';
  }

  void _replacePriorities(Map<int, int> changes) {
    for (var entry in changes.entries) {
      var file = _files[entry.key];
      _files[entry.key] = BtTaskFileDetail(
        path: file.path,
        size: file.size,
        completedBytes: file.completedBytes,
        priority: entry.value,
      );
    }
  }

  Future<void> _applyPriorities(Map<int, int> changes) async {
    if (changes.isEmpty || !mounted) return;
    var taskId = widget.taskId;
    var previous = <int, int>{
      for (var index in changes.keys) index: _files[index].priority,
    };
    setState(() {
      _busyIndices.addAll(changes.keys);
      _replacePriorities(changes);
    });
    try {
      var applied = await ref
          .read(btDownloadStoreProvider)
          .setFilePriorities(taskId, changes);
      if (!mounted) return;
      setState(() {
        if (applied.length == _files.length) {
          _files = [
            for (var i = 0; i < _files.length; i++)
              BtTaskFileDetail(
                path: _files[i].path,
                size: _files[i].size,
                completedBytes: _files[i].completedBytes,
                priority: applied[i],
              ),
          ];
        }
        _busyIndices.removeAll(changes.keys);
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _replacePriorities(previous);
        _busyIndices.removeAll(changes.keys);
      });
      unawaited(BtInfobar.error(context, '文件选择更新失败：$error'));
    }
  }

  void _toggleFile(int index, bool include) {
    unawaited(_applyPriorities({index: include ? 4 : 0}));
  }

  void _applyAll(bool include) {
    if (widget.truncated || _files.isEmpty) return;
    unawaited(
      _applyPriorities({
        for (var i = 0; i < _files.length; i++) i: include ? 4 : 0,
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    var error = widget.error;
    if (error != null && _files.isEmpty) {
      return _DetailTabError(error: error, onRetry: widget.onRetry);
    }
    if (_files.isEmpty && widget.loading) {
      return const Center(child: ProgressRing());
    }
    if (_files.isEmpty) {
      return const _DetailEmptyState(
        icon: FluentIcons.folder,
        title: '等待文件信息',
        description: '元数据就绪后会显示文件列表与独立进度',
      );
    }
    var footerParts = <String>[
      if (widget.truncated) '文件较多，仅显示前 ${_files.length} 个',
      if (!_canEdit) '下载完成后不可修改文件选择',
      if (error != null) '刷新失败，正在显示上次结果',
    ];
    return Column(
      children: [
        if (_canEdit)
          Padding(
            padding: EdgeInsets.fromLTRB(18, 14, 18, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '勾选可跳过或下载单个文件',
                    style: BTTypography.caption(context),
                  ),
                ),
                Button(
                  onPressed: widget.truncated ? null : () => _applyAll(true),
                  child: const Text('全部下载'),
                ),
                SizedBox(width: 8),
                Button(
                  onPressed: widget.truncated ? null : () => _applyAll(false),
                  child: const Text('全部跳过'),
                ),
              ],
            ),
          ),
        Expanded(
          child: _TableShell(
            footer: footerParts.isEmpty ? null : footerParts.join(' · '),
            header: const _TableHeader(
              columns: ['文件名', '类型', '进度', '已完成', '大小'],
              flexes: [5, 1, 2, 2, 2],
            ),
            itemCount: _files.length,
            itemBuilder: (context, index) {
              var file = _files[index];
              var extension = path.extension(file.path);
              var progress = (file.progress * 100).clamp(0, 100).toDouble();
              return _TableRow(
                flexes: const [5, 1, 2, 2, 2],
                columns: [
                  Row(
                    children: [
                      if (_canEdit)
                        Padding(
                          padding: EdgeInsets.only(right: 4),
                          child: Checkbox(
                            checked: !file.isSkipped,
                            onChanged: _busyIndices.contains(index)
                                ? null
                                : (value) => _toggleFile(index, value ?? true),
                            semanticLabel: '下载 ${file.path}',
                          ),
                        ),
                      Icon(
                        FluentIcons.document,
                        size: 14,
                        color: FluentTheme.of(context).accentColor,
                      ),
                      SizedBox(width: 8),
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
                    extension.isEmpty
                        ? '—'
                        : extension.substring(1).toUpperCase(),
                  ),
                  Padding(
                    padding: EdgeInsets.only(right: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${progress.toStringAsFixed(1)}%',
                          style: BTTypography.caption(context),
                        ),
                        SizedBox(height: 4),
                        ProgressBar(value: progress, strokeWidth: 4),
                      ],
                    ),
                  ),
                  Text(BTFileTool.formatSize(file.completedBytes)),
                  Text(BTFileTool.formatSize(file.size)),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
