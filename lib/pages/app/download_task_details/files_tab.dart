part of '../download_task_details.dart';

class _FilesTab extends ConsumerStatefulWidget {
  const _FilesTab({
    required this.files,
    required this.truncated,
    required this.totalFiles,
    required this.task,
    required this.taskId,
    required this.loading,
    this.error,
    this.onRetry,
  });

  final List<BtTaskFileDetail> files;
  final bool truncated;
  final int totalFiles;
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
  var _sortIndex = -1;
  var _ascending = true;

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
    return widget.task.sourceKind != 'http' &&
        state != 'completed' &&
        state != 'seeding';
  }

  void _toggleSort(int index) {
    setState(() {
      if (_sortIndex == index) {
        _ascending = !_ascending;
      } else {
        _sortIndex = index;
        _ascending = true;
      }
    });
  }

  List<_IndexedFile> _sortedFiles() {
    var files = [
      for (var index = 0; index < _files.length; index++)
        if (!_files[index].isPadding)
          _IndexedFile(index: index, file: _files[index]),
    ];
    if (_sortIndex == -1) return files;
    files.sort((a, b) {
      var result = switch (_sortIndex) {
        0 => _compareText(_fileName(a.file.path), _fileName(b.file.path)),
        1 => _compareText(_extension(a.file), _extension(b.file)),
        2 => a.file.progress.compareTo(b.file.progress),
        3 => a.file.completedBytes.compareTo(b.file.completedBytes),
        _ => a.file.size.compareTo(b.file.size),
      };
      if (result == 0) result = a.index.compareTo(b.index);
      return _ascending ? result : -result;
    });
    return files;
  }

  static int _compareText(String a, String b) =>
      a.toLowerCase().compareTo(b.toLowerCase());

  static String _extension(BtTaskFileDetail file) {
    var extension = path.extension(file.path);
    return extension.isEmpty ? '' : extension.substring(1).toLowerCase();
  }

  void _replacePriorities(Map<int, int> changes) {
    for (var entry in changes.entries) {
      var file = _files[entry.key];
      _files[entry.key] = BtTaskFileDetail(
        path: file.path,
        size: file.size,
        completedBytes: file.completedBytes,
        priority: entry.value,
        paddingFile: file.paddingFile,
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
                paddingFile: _files[i].paddingFile,
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
        for (var i = 0; i < _files.length; i++)
          if (!_files[i].isPadding) i: include ? 4 : 0,
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
    var files = _sortedFiles();
    if (files.isEmpty) {
      return const _DetailEmptyState(
        icon: FluentIcons.folder,
        title: '暂无可展示文件',
        description: '元数据中没有可下载的文件',
      );
    }
    var selectedCount = _files
        .where((file) => !file.isPadding && !file.isSkipped)
        .length;
    var footerParts = <String>[
      if (widget.truncated) '文件较多，已加载 ${files.length} / ${widget.totalFiles} 个',
      '已选下载 $selectedCount 个',
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
            header: _TableHeader(
              columns: ['文件名', '类型', '进度', '已完成', '大小'],
              flexes: const [7, 1, 2, 2, 2],
              sortIndex: _sortIndex,
              ascending: _ascending,
              onSort: _toggleSort,
            ),
            itemCount: files.length,
            itemBuilder: (context, index) {
              var entry = files[index];
              var file = entry.file;
              var fileIndex = entry.index;
              var extension = path.extension(file.path);
              var progress = (file.progress * 100).clamp(0, 100).toDouble();
              return _TableRow(
                flexes: const [7, 1, 2, 2, 2],
                columns: [
                  Row(
                    children: [
                      if (_canEdit)
                        Padding(
                          padding: EdgeInsets.only(right: 4),
                          child: Checkbox(
                            checked: !file.isSkipped,
                            onChanged: _busyIndices.contains(fileIndex)
                                ? null
                                : (value) =>
                                      _toggleFile(fileIndex, value ?? true),
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
                        child: Tooltip(
                          message: file.path,
                          child: Text(_fileName(file.path), softWrap: true),
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

  static String _fileName(String value) {
    var name = path.basename(value);
    if (name == '.' || name.isEmpty) return value.isEmpty ? '未知文件' : value;
    return name;
  }
}

class _IndexedFile {
  const _IndexedFile({required this.index, required this.file});

  final int index;
  final BtTaskFileDetail file;
}
