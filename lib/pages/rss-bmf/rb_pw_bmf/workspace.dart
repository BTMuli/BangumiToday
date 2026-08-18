part of '../rb_pw_bmf.dart';

mixin _RbpBmfWorkspace on _RbpBmfStateBase {
  Widget _buildWorkspace(BuildContext context) {
    if (_filterModel.filteredList.isEmpty) return _buildEmptyState(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        var compact = constraints.maxWidth < 900;
        var selected = _selectedModel();
        if (compact) {
          if (_showCompactDetail && selected != null) {
            return _buildDetailPane(context, selected, showBackButton: true);
          }
          return _buildBmfList(context, compact: true);
        }

        var listWidth = (constraints.maxWidth * 0.30).clamp(320.0, 420.0);
        return Row(
          children: [
            SizedBox(
              width: listWidth,
              child: _buildBmfList(context, compact: false),
            ),
            Container(width: 1, color: BTColors.divider(context)),
            Expanded(
              child: selected == null
                  ? _buildSelectPrompt(context)
                  : _buildDetailPane(context, selected),
            ),
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
        padding: EdgeInsets.all(10),
        itemCount: _filterModel.filteredList.length,
        separatorBuilder: (_, _) => SizedBox(height: 8),
        itemBuilder: (context, index) {
          var bmf = _filterModel.filteredList[index];
          return BmfCard(
            key: ValueKey(bmf.subject),
            bmf: bmf,
            pendingCount: _filterModel.pendingCounts[bmf.subject] ?? 0,
            selected: !compact && selected?.subject == bmf.subject,
            dense: true,
            onAutoUpdateChanged: (enabled) => _setAutoUpdate(bmf, enabled),
            onOpen: () => setState(() {
              selectedSubject = bmf.subject;
              _showCompactDetail = compact;
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
    var hasRss = bmf.rss != null && bmf.rss!.isNotEmpty;
    var hasDirectory = bmf.download != null && bmf.download!.isNotEmpty;
    var pendingCount = _filterModel.pendingCounts[bmf.subject] ?? 0;

    return ColoredBox(
      color: BTColors.surfacePrimary(context),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(18, 16, 14, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showBackButton) ...[
                  IconButton(
                    icon: BtIcon(FluentIcons.back, size: 15),
                    onPressed: () => setState(() => _showCompactDetail = false),
                  ),
                  SizedBox(width: 6),
                ],
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: FluentTheme.of(
                      context,
                    ).accentColor.withValues(alpha: 0.14),
                    borderRadius: BTRadius.mediumBR,
                  ),
                  child: Icon(
                    FluentIcons.media,
                    size: 18,
                    color: FluentTheme.of(context).accentColor,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bmf.title ?? '未命名番剧',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: BTTypography.title(context),
                      ),
                      SizedBox(height: 5),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            'Bangumi #${bmf.subject}',
                            style: BTTypography.caption(context),
                          ),
                          if (bmf.airDate != null && bmf.airDate!.isNotEmpty)
                            Text(
                              '首播 ${bmf.airDate}',
                              style: BTTypography.caption(context),
                            ),
                          if (pendingCount > 0)
                            _buildStatusBadge(
                              context,
                              label: '$pendingCount 条更新',
                              active: true,
                            ),
                          _buildStatusBadge(
                            context,
                            label: bmf.autoUpdate ? 'RSS 自动更新' : 'RSS 手动更新',
                            active: bmf.autoUpdate,
                          ),
                          _buildStatusBadge(
                            context,
                            label: hasRss ? 'RSS 已关联' : '缺少 RSS',
                            active: hasRss,
                          ),
                          _buildStatusBadge(
                            context,
                            label: hasDirectory ? '目录已关联' : '缺少目录',
                            active: hasDirectory,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 10),
                FilledButton(
                  onPressed: () => _editConfiguration(bmf),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(FluentIcons.edit, size: 13),
                      SizedBox(width: 6),
                      const Text('编辑关联'),
                    ],
                  ),
                ),
                SizedBox(width: 6),
                Tooltip(
                  message: '复制标题',
                  child: IconButton(
                    icon: BtIcon(FluentIcons.copy, size: 14),
                    onPressed: () => _copyTitle(bmf),
                  ),
                ),
                Tooltip(
                  message: '打开番剧详情',
                  child: IconButton(
                    icon: BtIcon(FluentIcons.open_in_new_tab, size: 14),
                    onPressed: () => _navigateToDetail(bmf),
                    onLongPress: () => _addToNavOnly(bmf),
                  ),
                ),
                Tooltip(
                  message: '删除 BMF 关联',
                  child: IconButton(
                    icon: Icon(
                      FluentIcons.delete,
                      size: 14,
                      color: BTColors.errorLight(context),
                    ),
                    onPressed: () => _deleteBmf(bmf),
                  ),
                ),
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
        padding: EdgeInsets.all(16),
        child: _buildUnconfiguredCard(context, bmf),
      );
    }

    Widget rssPane() => _buildScrollableResourcePane(
      child: BmfRssExpander(
        key: ValueKey(_rssViewKey(bmf, pendingCount)),
        bmf: bmf,
        isConfig: true,
        maxHeight: 320,
        contentScrollable: false,
        expandable: false,
        contentScrollController: _rssPaneController,
        onDelete: () => _removeRss(bmf),
      ),
    );
    Widget filePane() => _buildScrollableResourcePane(
      child: BmfFileExpander(
        key: ValueKey('file-${bmf.subject}-${bmf.download}'),
        downloadDir: bmf.download!,
        subject: bmf.subject,
        maxHeight: 320,
        contentScrollable: false,
        expandable: false,
        contentScrollController: _filePaneController,
        onDelete: () => _removeDirectory(bmf),
      ),
    );

    if (!hasRss) return filePane();
    if (!hasDirectory) return rssPane();

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 700) {
          return Column(
            children: [
              Expanded(child: rssPane()),
              Container(height: 1, color: BTColors.divider(context)),
              Expanded(child: filePane()),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: rssPane()),
            Container(width: 1, color: BTColors.divider(context)),
            Expanded(child: filePane()),
          ],
        );
      },
    );
  }

  Widget _buildScrollableResourcePane({required Widget child}) {
    return Padding(padding: EdgeInsets.all(12), child: child);
  }

  Widget _buildStatusBadge(
    BuildContext context, {
    required String label,
    required bool active,
  }) {
    var color = active
        ? FluentTheme.of(context).accentColor
        : BTColors.warningLight(context);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BTRadius.roundBR,
      ),
      child: Text(
        label,
        style: BTTypography.caption(
          context,
        ).copyWith(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildUnconfiguredCard(BuildContext context, AppBmfModel bmf) {
    return Container(
      padding: EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: BTColors.surfaceSecondary(context),
        borderRadius: BTRadius.largeBR,
        border: Border.all(color: BTColors.divider(context)),
      ),
      child: Column(
        children: [
          Icon(
            FluentIcons.link,
            size: 36,
            color: BTColors.textTertiary(context),
          ),
          SizedBox(height: 10),
          Text('尚未建立资源关联', style: BTTypography.subtitle(context)),
          SizedBox(height: 5),
          Text(
            '添加 RSS 用于接收发布更新，添加本地目录用于查看已落地文件。',
            textAlign: TextAlign.center,
            style: BTTypography.caption(context),
          ),
          SizedBox(height: 12),
          Button(
            onPressed: () => _editConfiguration(bmf),
            child: const Text('开始配置'),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectPrompt(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            FluentIcons.bulleted_list,
            size: 42,
            color: BTColors.textTertiary(context),
          ),
          SizedBox(height: 12),
          Text('选择一个番剧关联', style: BTTypography.subtitle(context)),
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
            _filterModel.configurationFilter ==
                    BmfConfigurationFilter.incomplete
                ? FluentIcons.completed
                : MdiIcons.linkOff,
            size: 46,
            color: BTColors.textTertiary(context),
          ),
          SizedBox(height: 12),
          Text(
            _filterModel.searchQuery.isNotEmpty
                ? '没有找到匹配的番剧'
                : _filterModel.configurationFilter ==
                      BmfConfigurationFilter.updates
                ? '没有待处理更新'
                : _filterModel.configurationFilter ==
                      BmfConfigurationFilter.autoUpdate
                ? '没有开启自动更新的 BMF'
                : _filterModel.configurationFilter ==
                      BmfConfigurationFilter.manualUpdate
                ? '没有关闭自动更新的 BMF'
                : _filterModel.configurationFilter ==
                      BmfConfigurationFilter.incomplete
                ? '当前关联均已补全'
                : '暂无 BMF 关联',
            style: BTTypography.subtitle(context),
          ),
          SizedBox(height: 5),
          Text(
            _filterModel.searchQuery.isNotEmpty
                ? '尝试其他标题或 Bangumi ID'
                : '可以在番剧详情页创建 BMF 关联',
            style: BTTypography.caption(context),
          ),
        ],
      ),
    );
  }
}
