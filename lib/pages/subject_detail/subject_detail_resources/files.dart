part of '../subject_detail_resources.dart';

extension _ResourceFiles on _SubjectDetailResourcesState {
  void _applyFiles(SubjectLocalFiles snapshot) {
    _files = snapshot.files;
    _fileSizes = snapshot.sizes;
    _fileStateUnknown = snapshot.stateUnknown;
    _dirState = snapshot.downloadState;
  }

  Future<void> _refreshFiles() async {
    try {
      await ref
          .read(subjectLocalFilesProvider(widget.subjectId).notifier)
          .refresh();
    } catch (error) {
      BTLogTool.warn('读取详情页下载目录失败：${error.runtimeType}');
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
      rules: ref.watch(subjectEpisodeRulesProvider(widget.subjectId)),
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
              () => showSubjectFileEpisodes(
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
