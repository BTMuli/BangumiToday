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
      var filesChanged =
          _files.length != files.length ||
          Iterable<int>.generate(
            files.length,
          ).any((i) => _files[i] != files[i]);
      if (filesChanged) {
        ref.invalidate(subjectPlaybackFilesProvider(widget.subjectId));
      }
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
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: _iconAction(
                '章节文件与自动匹配',
                FluentIcons.link,
                () =>
                    showSubjectEpisodeFiles(context, subject: widget.subjectId),
              ),
            ),
          ),
          Expanded(
            child: _emptyState(
              '尚未设置下载目录，也可添加视频文件关联剧集',
              action: () => _run(_chooseDirectory),
              label: '选择目录',
            ),
          ),
        ],
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
                    '章节文件与自动匹配',
                    FluentIcons.link,
                    () => showSubjectEpisodeFiles(
                      context,
                      subject: widget.subjectId,
                    ),
                  ),
                  _iconAction(
                    '刷新文件',
                    FluentIcons.refresh,
                    _refreshingFiles
                        ? null
                        : () async {
                            ref.invalidate(
                              subjectPlaybackFilesProvider(widget.subjectId),
                            );
                            await _refreshFiles();
                          },
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
                    '移除下载目录',
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
    var filePath = PlaybackPaths.resolveTaskPath(directory, file);
    var links =
        ref.watch(playbackEpisodeLinkSnapshotProvider).value ?? const {};
    var linked = links[PlaybackItem.pathKey(filePath)];
    var chapters = video
        ? ref.watch(subjectFileEpisodesProvider(widget.subjectId))
        : null;
    var effective = resolvePlaybackEpisodeFiles(
      subject: widget.subjectId,
      files: [filePath],
      episodes: (chapters?.value ?? []).map(episodeMarkChapter),
      manualLinks: links,
    )[PlaybackItem.pathKey(filePath)];
    var chapter = chapters?.value
        ?.where((episode) => episode.id == effective?.episode)
        .firstOrNull;
    return BmfFileItem(
      file: file,
      backgroundColor: SubjectDetailColors.card(context),
      fileSize: _fileSizes[file],
      state: state,
      stateUnknown: _fileStateUnknown,
      spacious: true,
      subtitle: !video
          ? null
          : Text(
              chapter != null
                  ? '${linked == null ? '自动匹配' : '手动修正'}：'
                        '${subjectFileEpisodeLabel(chapter)}'
                  : chapters?.isLoading == true
                  ? '正在匹配章节…'
                  : chapters?.hasError == true
                  ? '章节信息加载失败，请重试'
                  : linked?.subject != null &&
                        linked?.subject != widget.subjectId
                  ? '已关联其他条目'
                  : linked?.excluded == true
                  ? '不对应章节'
                  : linked != null
                  ? '关联章节已不存在，请重新关联'
                  : '未能自动匹配，可手动修正',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: BTTypography.caption(context),
            ),
      actions: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (video)
            _iconAction(
              '查看章节匹配或手动修正',
              FluentIcons.link,
              () => showSubjectEpisodeFiles(
                context,
                subject: widget.subjectId,
                filePath: filePath,
              ),
            ),
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
