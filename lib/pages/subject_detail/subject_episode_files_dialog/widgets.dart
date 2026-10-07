part of '../subject_episode_files_dialog.dart';

extension _EpisodeFilesLayout on _SubjectEpisodeFilesDialogState {
  Widget _buildFilesHeader() {
    var episode = widget.episode;
    var file = widget.filePath;
    var target = episode != null
        ? subjectFileEpisodeLabel(episode)
        : path.basename(file!);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: FluentTheme.of(
                  context,
                ).accentColor.withValues(alpha: 0.12),
                borderRadius: BTRadius.mediumBR,
              ),
              child: Icon(
                _editingFile ? FluentIcons.link : FluentIcons.video,
                size: 20,
                color: FluentTheme.of(context).accentColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _editingFile ? '文件关联剧集' : '剧集关联文件',
                style: BTTypography.title(context),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: _filePanelDecoration(),
          child: Row(
            children: [
              Icon(
                file == null ? FluentIcons.video : FluentIcons.page,
                size: 16,
                color: BTColors.textSecondary(context),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Tooltip(
                  message: file ?? target,
                  child: Text(
                    target,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: BTTypography.bodyStrong(context),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  BoxDecoration _filePanelDecoration() => BoxDecoration(
    color: BTColors.surfaceSecondary(context),
    borderRadius: BTRadius.mediumBR,
    border: Border.all(color: BTColors.divider(context)),
  );

  Widget _fileActionLabel(IconData icon, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [Icon(icon, size: 14), const SizedBox(width: 8), Text(label)],
  );

  Widget _fileBadge(String label, {bool highlighted = false}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: highlighted
          ? FluentTheme.of(context).accentColor.withValues(alpha: 0.12)
          : BTColors.surfaceTertiary(context),
      borderRadius: BTRadius.smallBR,
    ),
    child: Text(
      label,
      style: BTTypography.caption(context).copyWith(
        color: highlighted
            ? FluentTheme.of(context).accentColor
            : BTColors.textSecondary(context),
      ),
    ),
  );

  Widget _buildDirectoryBar(bool canChoose) {
    var directory = _directory;
    var hasDirectory = directory != null && directory.isNotEmpty;
    var info = Row(
      children: [
        Icon(
          FluentIcons.folder_open,
          size: 20,
          color: BTColors.textSecondary(context),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('下载目录', style: BTTypography.bodyStrong(context)),
              const SizedBox(height: 4),
              Tooltip(
                message: hasDirectory ? directory : '选择目录后自动扫描视频文件',
                child: Text(
                  hasDirectory ? directory : '尚未设置，可单独添加视频文件',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: BTTypography.caption(context),
                ),
              ),
            ],
          ),
        ),
      ],
    );
    var actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Button(
          onPressed: canChoose ? () => _run(_chooseDirectory) : null,
          child: Text(hasDirectory ? '更换目录' : '选择目录'),
        ),
        const SizedBox(width: 4),
        Tooltip(
          message: '重新扫描文件',
          child: IconButton(
            icon: const Icon(FluentIcons.refresh, size: 16),
            onPressed: canChoose
                ? () => _run(() async {
                    ref.invalidate(
                      subjectPlaybackFilesProvider(widget.subject),
                    );
                    await _loadFiles();
                  })
                : null,
          ),
        ),
      ],
    );
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _filePanelDecoration(),
      child: LayoutBuilder(
        builder: (_, constraints) {
          if (constraints.maxWidth < 460) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [info, const SizedBox(height: 12), actions],
            );
          }
          return Row(
            children: [
              Expanded(child: info),
              const SizedBox(width: 12),
              actions,
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyFiles(bool loading, bool canChoose) => LayoutBuilder(
    builder: (_, constraints) {
      var compact = constraints.maxHeight < 200;
      var minimal = constraints.maxHeight < 140;
      return Container(
        padding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: minimal
              ? 8
              : compact
              ? 12
              : 28,
        ),
        decoration: _filePanelDecoration(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!compact) ...[
              Icon(
                FluentIcons.video,
                size: 32,
                color: FluentTheme.of(context).accentColor,
              ),
              const SizedBox(height: 12),
            ],
            Text(
              loading ? '正在查找视频文件' : '还没有视频文件',
              style: compact
                  ? BTTypography.bodyStrong(context)
                  : BTTypography.subtitle(context),
              textAlign: TextAlign.center,
            ),
            if (!minimal) ...[
              const SizedBox(height: 6),
              Text(
                loading ? '正在扫描本地文件并加载章节关联' : '选择下载目录自动扫描，或添加单个视频文件。',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: BTTypography.caption(context),
                textAlign: TextAlign.center,
              ),
            ],
            if (!loading) ...[
              SizedBox(height: minimal ? 8 : 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  FilledButton(
                    onPressed: canChoose ? () => _run(_chooseDirectory) : null,
                    child: _fileActionLabel(FluentIcons.folder_open, '选择目录'),
                  ),
                  Button(
                    onPressed: canChoose ? () => _run(_pickFile) : null,
                    child: _fileActionLabel(FluentIcons.add, '添加文件'),
                  ),
                ],
              ),
            ],
          ],
        ),
      );
    },
  );

  Widget _buildListViewport(Widget sliver, int count, double rowExtent) =>
      SizedBox(
        height: (count * rowExtent).clamp(rowExtent, rowExtent * 5),
        child: Container(
          decoration: _filePanelDecoration(),
          clipBehavior: Clip.antiAlias,
          child: CustomScrollView(
            controller: _listScrollController,
            primary: false,
            slivers: [sliver],
          ),
        ),
      );

  Widget _buildFileList(
    List<String> files,
    String? selected,
    Map<String, PlaybackEpisodeLink> links,
    Map<String, PlaybackEpisodeLink> matched,
    List<BangumiEpisode> episodes,
    double rowExtent,
  ) => _buildListViewport(
    SliverLayoutBuilder(
      builder: (_, constraints) {
        var key = selected == null ? null : PlaybackItem.pathKey(selected);
        _revealSelectedRow(
          key,
          files.indexWhere((file) => PlaybackItem.pathKey(file) == key),
          files.length,
          rowExtent,
          constraints.viewportMainAxisExtent,
        );
        return SliverFixedExtentList(
          itemExtent: rowExtent,
          delegate: SliverChildBuilderDelegate((_, index) {
            var file = files[index];
            var key = PlaybackItem.pathKey(file);
            var link = links[key];
            var chapter = episodes
                .where((e) => e.id == matched[key]?.episode)
                .firstOrNull;
            var chapterLabel = chapter == null
                ? null
                : subjectFileEpisodeLabel(chapter);
            var label = link == null
                ? chapter == null
                      ? '未匹配 · 请选择对应章节'
                      : '自动匹配 · $chapterLabel'
                : link.subject != widget.subject
                ? '已关联其他条目'
                : link.excluded
                ? '不匹配 · 不对应章节'
                : chapter == null
                ? '关联章节已不存在'
                : '手动修正 · $chapterLabel';
            var checked =
                selected != null && PlaybackItem.pathKey(selected) == key;
            if (checked && widget.episode != null && _selectedEpisode == 0) {
              label = '待移除关联 · 保存修正后生效';
            }
            return _buildAssociationRow<String>(
              value: key,
              checked: checked,
              title: path.basename(file),
              subtitle: label,
              tooltip: '$file\n$label',
              enabled: !_busy,
            );
          }, childCount: files.length),
        );
      },
    ),
    files.length,
    rowExtent,
  );

  Widget _buildEpisodeToolbar(
    int count,
    int? selected, {
    required bool enabled,
  }) => Wrap(
    spacing: 8,
    runSpacing: 4,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      Text('选择剧集', style: BTTypography.bodyStrong(context)),
      _fileBadge('$count 集'),
      _buildUnmatchedEpisodeAction(selected == 0, enabled: enabled),
    ],
  );

  Widget _buildUnmatchedEpisodeAction(bool checked, {required bool enabled}) =>
      Semantics(
        selected: checked,
        inMutuallyExclusiveGroup: true,
        child: Tooltip(
          message: '该文件不关联任何剧集，保存修正后生效',
          child: Button(
            onPressed: enabled ? () => _selectEpisode(0) : null,
            style: _episodeChoiceStyle(checked),
            child: _fileActionLabel(FluentIcons.remove, '不匹配'),
          ),
        ),
      );

  ButtonStyle _episodeChoiceStyle(bool checked, {bool compact = false}) =>
      ButtonStyle(
        padding: compact
            ? const WidgetStatePropertyAll(
                EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              )
            : null,
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: compact ? BTRadius.smallBR : BTRadius.mediumBR,
            side: BorderSide(
              color: checked
                  ? FluentTheme.of(context).accentColor.withValues(alpha: 0.6)
                  : BTColors.divider(context),
            ),
          ),
        ),
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.isDisabled) return BTColors.surfaceSecondary(context);
          if (checked || states.isHovered || states.isPressed) {
            return FluentTheme.of(context).accentColor.withValues(
              alpha: states.isPressed
                  ? 0.24
                  : checked
                  ? 0.16
                  : 0.08,
            );
          }
          return BTColors.surfaceTertiary(context);
        }),
      );

  Widget _buildEpisodeGrid(
    List<BangumiEpisode> episodes,
    int? selected,
    int? currentEpisode,
    PlaybackEpisodeLink? linked,
    double rowExtent, {
    required bool enabled,
  }) {
    if (episodes.isEmpty) {
      return Container(
        height: rowExtent * 2,
        decoration: _filePanelDecoration(),
        alignment: Alignment.center,
        child: Text(
          enabled ? '暂无剧集信息，可选择不匹配' : '正在加载剧集信息…',
          style: BTTypography.caption(context),
        ),
      );
    }
    var byType = <BangumiEpType, List<BangumiEpisode>>{};
    for (var episode in episodes) {
      byType.putIfAbsent(episode.type, () => []).add(episode);
    }
    var groups = [
      for (var type in BangumiEpType.values)
        if (byType.containsKey(type))
          (type, byType[type]!..sort((a, b) => a.sort.compareTo(b.sort))),
    ];
    var showGroups = byType.keys.any((type) => type != BangumiEpType.main);
    var numbers = {
      for (var episode in episodes)
        episode.id: episode.sort == episode.sort.truncateToDouble()
            ? episode.sort.toInt().toString()
            : episode.sort.toString(),
    };
    var textScaler = MediaQuery.textScalerOf(context);
    var numberStyle = BTTypography.body(context).copyWith(fontSize: 16);
    var tileWidth = textScaler.scale(40);
    var painter = TextPainter(
      textDirection: Directionality.of(context),
      textScaler: textScaler,
    );
    for (var number in numbers.values) {
      painter.text = TextSpan(text: number, style: numberStyle);
      painter.layout();
      if (painter.width + 16 > tileWidth) tileWidth = painter.width + 16;
    }
    painter.dispose();
    return LayoutBuilder(
      builder: (_, constraints) {
        const gap = 8.0;
        const groupGap = 16.0;
        var availableWidth = (constraints.maxWidth - gap * 2).clamp(
          0.0,
          double.infinity,
        );
        var width = tileWidth.clamp(0.0, availableWidth);
        var columns = ((availableWidth + gap) / (width + gap)).floor().clamp(
          1,
          episodes.length,
        );
        var tileExtent = textScaler.scale(24) + 12;
        var headerExtent = textScaler.scale(24);
        var top = gap;
        var selectedRow = -1;
        var selectedTop = gap;
        for (var (index, (_, group)) in groups.indexed) {
          if (index > 0) top += groupGap;
          if (showGroups) top += headerExtent + gap;
          var selectedIndex = group.indexWhere((e) => e.id == selected);
          if (selectedIndex >= 0) {
            selectedRow = selectedIndex ~/ columns;
            selectedTop = top;
          }
          var rows = (group.length + columns - 1) ~/ columns;
          top += rows * tileExtent + (rows - 1) * gap;
        }
        var height = top + gap;
        return SizedBox(
          height: height.clamp(tileExtent + gap * 2, tileExtent * 6 + gap * 7),
          child: Container(
            decoration: _filePanelDecoration(),
            clipBehavior: Clip.antiAlias,
            child: LayoutBuilder(
              builder: (_, viewport) {
                _revealSelectedRow(
                  selected == null ? null : 'episode-$selected',
                  selectedRow,
                  episodes.length,
                  tileExtent + gap,
                  viewport.maxHeight,
                  topPadding: selectedTop,
                );
                return CustomScrollView(
                  controller: _listScrollController,
                  primary: false,
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.all(gap),
                      sliver: SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (var (index, (type, group)) in groups.indexed)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (index > 0)
                                    const SizedBox(height: groupGap),
                                  if (showGroups) ...[
                                    SizedBox(
                                      height: headerExtent,
                                      child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          '${type.label} · ${group.length} 集',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: BTTypography.bodyStrong(
                                            context,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: gap),
                                  ],
                                  Wrap(
                                    spacing: gap,
                                    runSpacing: gap,
                                    children: [
                                      for (var episode in group)
                                        SizedBox(
                                          width: width,
                                          height: tileExtent,
                                          child: _buildEpisodeChoice(
                                            episode,
                                            numbers[episode.id]!,
                                            selected,
                                            currentEpisode,
                                            linked,
                                            enabled: enabled,
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildEpisodeChoice(
    BangumiEpisode episode,
    String number,
    int? selected,
    int? currentEpisode,
    PlaybackEpisodeLink? linked, {
    required bool enabled,
  }) {
    var checked = episode.id == selected;
    var metadata = [
      if (episode.id == currentEpisode) linked == null ? '当前自动匹配' : '当前手动关联',
      if (episode.airDate.isNotEmpty) episode.airDate,
      if (episode.duration.isNotEmpty) episode.duration,
    ];
    return Semantics(
      label: subjectFileEpisodeLabel(episode),
      selected: checked,
      inMutuallyExclusiveGroup: true,
      child: Tooltip(
        message: [
          subjectFileEpisodeLabel(episode),
          if (metadata.isNotEmpty) metadata.join(' · '),
        ].join('\n'),
        child: Button(
          onPressed: enabled ? () => _selectEpisode(episode.id) : null,
          style: _episodeChoiceStyle(checked, compact: true),
          child: Text(
            number,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: BTTypography.body(context).copyWith(
              fontSize: 16,
              color: enabled
                  ? BTColors.textPrimary(context)
                  : FluentTheme.of(context).resources.textFillColorDisabled,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAssociationRow<T>({
    required T value,
    required bool checked,
    required String title,
    String? subtitle,
    String? tooltip,
    required bool enabled,
  }) => Container(
    margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
    padding: const EdgeInsets.symmetric(horizontal: 10),
    decoration: BoxDecoration(
      color: checked
          ? FluentTheme.of(context).accentColor.withValues(alpha: 0.1)
          : Colors.transparent,
      borderRadius: BTRadius.smallBR,
      border: Border.all(
        color: checked
            ? FluentTheme.of(context).accentColor.withValues(alpha: 0.4)
            : Colors.transparent,
      ),
    ),
    alignment: Alignment.centerLeft,
    child: Tooltip(
      message: tooltip ?? [title, ?subtitle].join('\n'),
      child: RadioButton<T>(
        value: value,
        enabled: enabled,
        content: SizedBox(
          width: double.infinity,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: BTTypography.body(context),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: BTTypography.caption(context),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );

  Widget _buildFileError(String text, {Widget? action}) {
    var color = BTColors.errorLight(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BTRadius.mediumBR,
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(FluentIcons.error_badge, size: 16, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Tooltip(
              message: text,
              child: Text(
                text,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: BTTypography.caption(context),
              ),
            ),
          ),
          if (action != null) ...[const SizedBox(width: 8), action],
        ],
      ),
    );
  }
}
