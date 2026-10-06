part of '../subject_detail_resources.dart';

extension _ResourceFiles on _SubjectDetailResourcesState {
  void _syncFileTimer() {
    var poll = _active && _showFiles && _dirState?.hasActiveTasks == true;
    if (poll) {
      _fileTimer ??= Timer.periodic(
        const Duration(seconds: 5),
        (_) => unawaited(_refreshFiles()),
      );
    } else {
      _fileTimer?.cancel();
      _fileTimer = null;
    }
  }

  List<BtTaskSnapshot> _directoryTasks(String directory) => [
    for (var task in ref.read(btDownloadStoreProvider).tasks)
      if (path.normalize(task.savePath).toLowerCase() ==
          path.normalize(directory).toLowerCase())
        task,
  ];

  Future<void> _refreshFiles() async {
    if (_refreshingFiles) {
      _filesQueued = true;
      return;
    }
    var directory = _bmf.download;
    if (directory == null || directory.isEmpty || !mounted) return;
    _update(() => _refreshingFiles = true);
    var generation = ++_fileGeneration;
    try {
      var files = await _fileTool.getFileNames(directory, recursive: true);
      files.sort(PlaybackPaths.naturalCompare);
      var sizes = <String, int>{};
      for (var file in files) {
        var size = _fileTool.getFileSize(
          PlaybackPaths.resolveTaskPath(directory, file),
        );
        if (size >= 0) sizes[file] = size;
      }
      if (!mounted || generation != _fileGeneration) return;
      var detailsById = <String, List<BtTaskFileDetail>>{};
      for (var task in _directoryTasks(directory)) {
        try {
          var details = <BtTaskFileDetail>[];
          var offset = 0;
          while (true) {
            var result = await ref
                .read(btDownloadStoreProvider.notifier)
                .taskFiles(task.id, offset: offset);
            if (!mounted || generation != _fileGeneration) return;
            details.addAll(result.files);
            if (!result.truncated) break;
            var next = result.nextOffset;
            if (next == null || next <= offset) throw StateError('下载文件列表分页未就绪');
            offset = next;
          }
          detailsById[task.id] = details;
        } catch (error) {
          BTLogTool.warn('刷新详情页文件下载状态失败：${error.runtimeType}');
        }
      }
      if (!mounted || generation != _fileGeneration) return;
      var tasks = ref.read(btDownloadStoreProvider).tasks;
      var state = computeDirDownloadState(
        dir: directory,
        tasks: tasks,
        fileDetailsByTaskId: detailsById,
        dirFileNames: files,
      );
      _update(() {
        _files = files;
        _fileSizes = sizes;
        _fileStateUnknown = _directoryTasks(
          directory,
        ).any((task) => !detailsById.containsKey(task.id));
        _dirState = state;
        _fileError = null;
      });
      _syncFileTimer();
    } catch (error) {
      if (!mounted || generation != _fileGeneration) return;
      _update(() => _fileError = '读取下载目录失败，请重试');
      BTLogTool.warn('读取详情页下载目录失败：${error.runtimeType}');
    } finally {
      if (mounted) {
        _update(() => _refreshingFiles = false);
        if (_filesQueued) {
          _filesQueued = false;
          unawaited(_refreshFiles());
        }
      }
    }
  }

  Future<void> _deleteFile(
    String directory,
    String file,
    bool incomplete,
  ) async {
    var confirmed = await showConfirm(
      context,
      title: '删除文件',
      content: incomplete
          ? '该文件尚未下载完成，删除可能中断下载任务。确定删除 $file 吗？'
          : '确定删除 $file 吗？',
    );
    if (!confirmed || !mounted) return;
    var success = await _fileTool.deleteFile(
      PlaybackPaths.resolveTaskPath(directory, file),
    );
    if (!mounted) return;
    if (success) {
      await _refreshFiles();
    } else {
      await BtInfobar.error(context, '删除文件失败');
    }
  }

  Widget _buildFiles() {
    var directory = _bmf.download;
    if (directory == null || directory.isEmpty) {
      return _emptyState(
        '尚未设置下载目录',
        action: () => _run(_chooseDirectory),
        label: '选择目录',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SelectableText(directory, style: BTTypography.caption(context)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _iconAction(
                    '刷新文件',
                    FluentIcons.refresh,
                    _refreshingFiles ? null : _refreshFiles,
                  ),
                  _iconAction(
                    '打开下载目录',
                    FluentIcons.folder_open,
                    () => _run(() async {
                      if (!await _fileTool.openDir(directory) && mounted) {
                        await BtInfobar.error(context, '下载目录不存在');
                      }
                    }),
                  ),
                  _iconAction(
                    '移除目录记录',
                    FluentIcons.delete,
                    _busy ? null : () => _run(_removeDirectory),
                  ),
                  if (_dirState?.hasIncompleteFiles == true)
                    _badge('${_dirState!.incompleteFileCount} 个文件下载中'),
                  if (_dirState?.hasActiveTasks == true)
                    _badge('${_dirState!.activeTaskCount} 个未完成任务'),
                  if (_refreshingFiles)
                    const SizedBox.square(
                      dimension: 16,
                      child: ProgressRing(strokeWidth: 2),
                    ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: _fileError != null
              ? _emptyState(_fileError!, action: _refreshFiles, label: '重试')
              : _files.isEmpty
              ? _emptyState(_refreshingFiles ? '正在读取下载目录…' : '下载目录中暂无文件')
              : ListView.separated(
                  key: PageStorageKey(
                    'subject-${widget.subjectId}-files-$directory',
                  ),
                  primary: false,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: _files.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, index) =>
                      _buildFile(directory, _files[index]),
                ),
        ),
      ],
    );
  }

  Widget _buildFile(String directory, String file) {
    var state = _dirState?.stateFor(file);
    var incomplete = state?.isIncomplete == true || _fileStateUnknown;
    var video = PlaybackPaths.isVideo(file);
    return BmfFileItem(
      file: file,
      backgroundColor: SubjectDetailColors.card(context),
      fileSize: _fileSizes[file],
      state: state,
      stateUnknown: _fileStateUnknown,
      spacious: true,
      actions: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (video && !incomplete) ...[
            _iconAction(
              '应用内播放',
              FluentIcons.play,
              () => openLocalPlayback(
                context,
                ref,
                PlaybackPaths.resolveTaskPath(directory, file),
                subject: widget.subjectId,
              ),
            ),
            _iconAction(
              '使用外部播放器打开',
              FluentIcons.open_file,
              () => _run(() async {
                await launchUrlString(
                  Uri.file(
                    PlaybackPaths.resolveTaskPath(directory, file),
                  ).toString(),
                );
              }),
            ),
          ],
          _iconAction(
            '删除文件',
            FluentIcons.delete,
            _busy
                ? null
                : () => _run(() => _deleteFile(directory, file, incomplete)),
          ),
        ],
      ),
    );
  }
}
