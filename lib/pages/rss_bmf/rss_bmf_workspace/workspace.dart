part of '../rss_bmf_workspace.dart';

mixin _RssBmfWorkspacePane on _RssBmfWorkspaceStateBase {
  Widget _buildWorkspace(BuildContext context) {
    if (_filterModel.filteredList.isEmpty) return _buildEmptyState(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        var compact = constraints.maxWidth < 880;
        var selected = _selectedModel();
        if (compact) {
          if (_showCompactDetail && selected != null) {
            return _buildDetailPane(context, selected, showBackButton: true);
          }
          return _buildBmfList(context, compact: true);
        }

        var maximumListWidth = (constraints.maxWidth - 548).clamp(280.0, 460.0);
        var listWidth = (_listPaneWidth ?? 320).clamp(280.0, maximumListWidth);
        return Row(
          children: [
            SizedBox(
              width: listWidth,
              child: _buildBmfList(context, compact: false),
            ),
            Tooltip(
              message: '拖动调整番剧列表宽度，双击恢复',
              child: MouseRegion(
                cursor: SystemMouseCursors.resizeLeftRight,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onDoubleTap: () => setState(() => _listPaneWidth = null),
                  onHorizontalDragUpdate: (details) => setState(() {
                    _listPaneWidth =
                        ((_listPaneWidth ?? listWidth).clamp(
                                  280.0,
                                  maximumListWidth,
                                ) +
                                details.delta.dx)
                            .clamp(280.0, maximumListWidth);
                  }),
                  child: SizedBox(
                    width: 8,
                    child: Center(
                      child: Container(
                        width: 1,
                        color: BTColors.divider(context),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(child: _buildDetailPane(context, selected!)),
          ],
        );
      },
    );
  }

  Widget _buildBmfList(BuildContext context, {required bool compact}) {
    var selected = _selectedModel();
    return ColoredBox(
      color: BTColors.surfaceSecondary(context),
      child: ListView.separated(
        controller: _bmfListController,
        padding: const EdgeInsets.all(12),
        itemCount: _filterModel.filteredList.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          var bmf = _filterModel.filteredList[index];
          return BmfCard(
            key: ValueKey(bmf.subject),
            bmf: bmf,
            imageUrl: _filterModel.subjectData[bmf.subject]?.imageUrl,
            displayTitle: _filterModel.titleFor(bmf),
            seasonLabel: _filterModel.quarterFor(bmf).label,
            pendingCount: _filterModel.pendingCounts[bmf.subject] ?? 0,
            selected: !compact && selected?.subject == bmf.subject,
            dense: true,
            onAutoUpdateChanged: (enabled) => _setAutoUpdate(bmf, enabled),
            onOpen: () => setState(() {
              selectedSubject = bmf.subject;
              _showCompactDetail = compact;
              _showLocalFiles = false;
            }),
            onDelete: () => _deleteBmf(bmf, requireConfirmation: false),
          );
        },
      ),
    );
  }

  Widget _buildDetailPane(
    BuildContext context,
    AppBmfModel bmf, {
    bool showBackButton = false,
  }) {
    var hasRss = BmfFilterModel.hasRss(bmf);
    var hasDirectory = BmfFilterModel.hasDirectory(bmf);
    var airDate = _filterModel.airDateFor(bmf);
    var pendingCount = _filterModel.pendingCounts[bmf.subject] ?? 0;
    var title = _filterModel.titleFor(bmf);

    var actions = Wrap(
      alignment: WrapAlignment.end,
      spacing: 4,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Button(
          onPressed: () => _editConfiguration(bmf),
          child: const Text('编辑关联'),
        ),
        if (hasRss)
          BmfAutoUpdateButton(
            enabled: bmf.autoUpdate,
            onChanged: (enabled) => _setAutoUpdate(bmf, enabled),
          ),
        Tooltip(
          message: '查找 RSS',
          child: IconButton(
            icon: const BtIcon(FluentIcons.search, size: 15),
            onPressed: () => _searchRss(bmf),
          ),
        ),
        Tooltip(
          message: '复制标题',
          child: IconButton(
            icon: const BtIcon(FluentIcons.copy, size: 15),
            onPressed: () => _copyTitle(bmf),
          ),
        ),
        Tooltip(
          message: '打开番剧详情（长按添加到导航栏）',
          child: IconButton(
            icon: const BtIcon(FluentIcons.open_in_new_tab, size: 15),
            onPressed: () => _navigateToDetail(bmf),
            onLongPress: () => _addToNavOnly(bmf),
          ),
        ),
        Tooltip(
          message: '删除 BMF 关联',
          child: IconButton(
            icon: Icon(
              FluentIcons.delete,
              size: 15,
              color: BTColors.errorLight(context),
            ),
            onPressed: () => _deleteBmf(bmf),
          ),
        ),
      ],
    );

    return ColoredBox(
      color: BTColors.surfacePrimary(context),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showBackButton) ...[
                      IconButton(
                        icon: const BtIcon(FluentIcons.back, size: 15),
                        onPressed: () =>
                            setState(() => _showCompactDetail = false),
                      ),
                      const SizedBox(width: 8),
                    ],
                    SizedBox(
                      width: 48,
                      height: 68,
                      child: BtBangumiCover(
                        imageUrl:
                            _filterModel.subjectData[bmf.subject]?.imageUrl,
                        maxRequestEdge: BangumiCoverUrl.thumbMaxEdge,
                        borderRadius: BTRadius.smallBR,
                        errorBuilder: (context, {err}) => Container(
                          color: BTColors.surfaceSecondary(context),
                          child: const Icon(FluentIcons.media, size: 24),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Tooltip(
                            message: '$title\nBangumi #${bmf.subject}',
                            child: Text(
                              title,
                              style: BTTypography.subtitle(context),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 12,
                            runSpacing: 4,
                            children: [
                              Text(
                                _filterModel.quarterFor(bmf).label,
                                style: BTTypography.caption(context),
                              ),
                              if (airDate != null)
                                Text(
                                  '首播 $airDate',
                                  style: BTTypography.caption(context),
                                ),
                              Text(
                                hasRss
                                    ? (bmf.autoUpdate ? 'RSS 自动更新' : 'RSS 手动更新')
                                    : '缺少 RSS',
                                style: BTTypography.caption(context).copyWith(
                                  color: hasRss
                                      ? null
                                      : BTColors.warningLight(context),
                                ),
                              ),
                              if (!hasDirectory)
                                Text(
                                  '缺少目录',
                                  style: BTTypography.caption(context).copyWith(
                                    color: BTColors.warningLight(context),
                                  ),
                                ),
                              if (pendingCount > 0)
                                Text(
                                  '$pendingCount 条待处理',
                                  style: BTTypography.caption(context).copyWith(
                                    color: FluentTheme.of(context).accentColor,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                actions,
              ],
            ),
          ),
          Container(height: 1, color: BTColors.divider(context)),
          Expanded(
            child: _buildResourcePanes(
              context,
              bmf,
              hasRss: hasRss,
              hasDirectory: hasDirectory,
              pendingCount: pendingCount,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResourcePanes(
    BuildContext context,
    AppBmfModel bmf, {
    required bool hasRss,
    required bool hasDirectory,
    required int pendingCount,
  }) {
    if (!hasRss && !hasDirectory) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: _buildUnconfiguredCard(context, bmf),
      );
    }

    Widget rssPane() => BmfRssExpander(
      key: ValueKey(_rssViewKey(bmf, pendingCount)),
      bmf: bmf,
      isConfig: true,
      maxHeight: 320,
      contentScrollable: false,
      expandable: false,
      embedded: true,
      contentScrollController: _rssPaneController,
      onDelete: () => _removeRss(bmf),
    );
    Widget filePane() => BmfFileExpander(
      key: ValueKey('file-${bmf.subject}-${bmf.download}'),
      downloadDir: bmf.download!,
      subject: bmf.subject,
      maxHeight: 320,
      contentScrollable: false,
      expandable: false,
      embedded: true,
      contentScrollController: _filePaneController,
      onDelete: () => _removeDirectory(bmf),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        var canSplit = hasRss && hasDirectory && constraints.maxWidth >= 1100;
        var split = canSplit && _splitResources;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
              child: Row(
                children: [
                  if (hasRss && hasDirectory && !split) ...[
                    ToggleButton(
                      checked: !_showLocalFiles,
                      onChanged: (_) => setState(() => _showLocalFiles = false),
                      child: const Text('RSS 资源'),
                    ),
                    const SizedBox(width: 8),
                    ToggleButton(
                      checked: _showLocalFiles,
                      onChanged: (_) => setState(() => _showLocalFiles = true),
                      child: const Text('本地文件'),
                    ),
                  ] else
                    Text(
                      split
                          ? 'RSS 资源与本地文件'
                          : hasRss
                          ? 'RSS 资源'
                          : '本地文件',
                      style: BTTypography.bodyStrong(context),
                    ),
                  const Spacer(),
                  if (canSplit)
                    ToggleButton(
                      checked: split,
                      onChanged: (value) =>
                          setState(() => _splitResources = value),
                      child: const Text('并排查看'),
                    ),
                  if (!hasRss || !hasDirectory)
                    HyperlinkButton(
                      onPressed: () => _editConfiguration(bmf),
                      child: Text(hasRss ? '关联本地目录' : '关联 RSS'),
                    ),
                ],
              ),
            ),
            Expanded(
              child: split
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: rssPane()),
                        Container(width: 1, color: BTColors.divider(context)),
                        Expanded(child: filePane()),
                      ],
                    )
                  : (hasDirectory && (!hasRss || _showLocalFiles)
                        ? filePane()
                        : rssPane()),
            ),
          ],
        );
      },
    );
  }

  Widget _buildUnconfiguredCard(BuildContext context, AppBmfModel bmf) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: BTColors.surfaceSecondary(context),
        borderRadius: BTRadius.largeBR,
      ),
      child: Column(
        children: [
          Icon(
            FluentIcons.link,
            size: 36,
            color: BTColors.textTertiary(context),
          ),
          const SizedBox(height: 10),
          Text('尚未建立资源关联', style: BTTypography.subtitle(context)),
          const SizedBox(height: 5),
          Text(
            '添加 RSS 接收发布更新，关联本地目录查看下载文件。',
            textAlign: TextAlign.center,
            style: BTTypography.caption(context),
          ),
          const SizedBox(height: 12),
          Button(
            onPressed: () => _editConfiguration(bmf),
            child: const Text('开始配置'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _filterModel.hasActiveFilters
                ? FluentIcons.search
                : MdiIcons.linkOff,
            size: 46,
            color: BTColors.textTertiary(context),
          ),
          const SizedBox(height: 12),
          Text(
            _filterModel.totalCount == 0 ? '暂无 BMF 关联' : '当前筛选下没有匹配的番剧',
            style: BTTypography.subtitle(context),
          ),
          const SizedBox(height: 5),
          Text(
            _filterModel.totalCount == 0
                ? '在番剧详情页关联 RSS 或本地目录后，会显示在这里'
                : '尝试其他标题、季度或关联状态',
            style: BTTypography.caption(context),
          ),
          if (_filterModel.hasActiveFilters) ...[
            const SizedBox(height: 12),
            Button(onPressed: _resetFilters, child: const Text('清除全部筛选')),
          ],
        ],
      ),
    );
  }
}
