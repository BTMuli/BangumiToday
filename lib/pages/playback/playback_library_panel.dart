part of 'playback_page.dart';

/// 面板内容。为空时显示选集/记录两个标签页（内嵌播放页侧栏），
/// 指定时只显示其中一类（控制层与空态的独立浮出层）。
enum _PlaybackLibrarySection { playlist, history }

/// Each sidebar/flyout owns its scrolling and tab state. The fullscreen route
/// can therefore open the same compact library without sharing scroll clients.
class _PlaybackLibraryPanel extends ConsumerStatefulWidget {
  const _PlaybackLibraryPanel({
    super.key,
    required this.run,
    required this.openExternalPlayer,
    required this.openVideoDirectory,
    required this.openSubject,
    this.section,
  });

  final Future<void> Function(Future<void> Function()) run;
  final Future<void> Function(PlaybackItem) openExternalPlayer;
  final Future<void> Function(PlaybackItem) openVideoDirectory;
  final Future<void> Function(int) openSubject;
  final _PlaybackLibrarySection? section;

  @override
  ConsumerState<_PlaybackLibraryPanel> createState() =>
      _PlaybackLibraryPanelState();
}

class _PlaybackLibraryPanelState extends ConsumerState<_PlaybackLibraryPanel> {
  final _gridScroll = ScrollController();
  final _listScroll = ScrollController();
  final _historyScroll = ScrollController();
  final _historySearch = TextEditingController();
  final _menu = FlyoutController();
  final _expandedHistory = <String>{};
  String _historyQuery = '';
  late bool _showHistory;
  String? _lastPlayingKey;
  int _lastIndex = -1;
  int _columns = 4;
  PlaybackEpisodeLayout? _lastLayout;
  (String?, String)? _progressSignature;
  final _resolvedHistorySubjects = <int>{};
  bool _savingAutoMark = false;
  static const _cellHeight = 48.0;
  static const _rowHeight = 46.0;
  static const _gap = 6.0;
  static const _gridPadding = 8.0;
  static const _listPadding = 6.0;
  static const _minCellWidth = 56.0;

  /// 面板外框线宽；`Container` 会把 decoration 的边框计入内边距。
  static const _borderWidth = 1.0;

  /// 标题行高 32、上下内边距各 6、分隔线 1。
  static const _headerHeight = 45.0;

  /// 第二行高 32，与标题行相隔 4。
  static const _secondaryHeaderHeight = 36.0;
  bool _revealed = false;

  @override
  void initState() {
    super.initState();
    var store = ref.read(playbackStoreProvider);
    _showHistory =
        widget.section == _PlaybackLibrarySection.history ||
        (widget.section == null && store.playlist.isEmpty);
    _lastPlayingKey = store.current?.key;
    revealCurrent();
  }

  @override
  void dispose() {
    _gridScroll.dispose();
    _listScroll.dispose();
    _historyScroll.dispose();
    _historySearch.dispose();
    _menu.dispose();
    super.dispose();
  }

  void revealCurrent() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _showHistory) return;
      var store = ref.read(playbackStoreProvider);
      var layout = store.episodeLayout;
      var scroll = layout == PlaybackEpisodeLayout.list
          ? _listScroll
          : _gridScroll;
      if (!scroll.hasClients) return;
      var index = store.index;
      if (index < 0) return;
      var first = !_revealed;
      _revealed = true;
      var position = scroll.position;
      var height = layout == PlaybackEpisodeLayout.list
          ? _rowHeight
          : _cellHeight;
      var top = layout == PlaybackEpisodeLayout.list
          ? _listPadding + index * (_rowHeight + _gap)
          : _gridPadding + (index ~/ _columns) * (_cellHeight + _gap);
      if (top >= position.pixels &&
          top + height <= position.pixels + position.viewportDimension) {
        return;
      }
      var target = (top - position.viewportDimension / 2 + height / 2).clamp(
        0.0,
        position.maxScrollExtent,
      );
      if (first) {
        // 浮出层打开时直接就位，避免定位过程与入场动画叠加。
        scroll.jumpTo(target);
        return;
      }
      unawaited(
        scroll.animateTo(
          target,
          duration: BTTheme.animationDurationNormal,
          curve: BTTheme.animationCurve,
        ),
      );
    });
  }

  /// 选集浮出层的自然高度（含面板边框）：标题、加载状态、分隔线和当前排版
  /// 下的完整列表。记录页由最大高度与内部滚动处理。
  static double playlistFlyoutHeight({
    required int count,
    required PlaybackEpisodeLayout layout,
    required double width,
    required bool isOpening,
  }) {
    // 边框会缩进面板内容，列表实际宽度与列数按内宽计算。
    var innerWidth = width - 2 * _borderWidth;
    var content = switch (layout) {
      PlaybackEpisodeLayout.grid => () {
        var columns = _columnsFor(innerWidth);
        var rows = (count + columns - 1) ~/ columns;
        var spacing = rows > 1 ? (rows - 1) * _gap : 0.0;
        return 2 * _gridPadding + rows * _cellHeight + spacing;
      }(),
      PlaybackEpisodeLayout.list =>
        2 * _listPadding + count * (_rowHeight + _gap),
    };
    return _headerHeight +
        (isOpening ? _secondaryHeaderHeight : 0) +
        content +
        2 * _borderWidth;
  }

  /// 栏宽与 `_playlist` 共用同一列规则，浮出层高度才能与列表布局一致。
  static int _columnsFor(double width) =>
      ((width - 2 * _gridPadding + _gap) / (_minCellWidth + _gap))
          .floor()
          .clamp(1, 6);

  @override
  Widget build(BuildContext context) {
    var store = ref.watch(playbackStoreProvider);
    var account = ref.watch(
      episodeMarkProvider.select((value) => value.account),
    );
    // 观看进度只服务于选集页的标记按钮：记录页可见时先不同步，切回选集再拉，
    // 免得打开播放记录就顺带请求一遍 bgm 进度。
    if (!_showHistory) {
      var signature = (
        account,
        store.playlist.map(EpisodeMarkState.itemKey).join('\n'),
      );
      if (_progressSignature != signature) {
        _progressSignature = signature;
        var items = List<PlaybackItem>.of(store.playlist);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || _showHistory || _progressSignature != signature) {
            return;
          }
          unawaited(
            widget.run(
              () => ref.read(episodeMarkProvider.notifier).syncItems(items),
            ),
          );
        });
      }
    }
    var key = store.current?.key;
    if (key != _lastPlayingKey || store.index != _lastIndex) {
      // 只有内嵌侧栏的两个标签页跟随播放状态自动切换。
      if (widget.section == null) {
        if (key != null && _lastPlayingKey == null) _showHistory = false;
        if (key == null && _lastPlayingKey != null) _showHistory = true;
      }
      _lastPlayingKey = key;
      _lastIndex = store.index;
      revealCurrent();
    }
    // 切换排版后滚动位置属于另一份控制器，重新定位到当前集。
    if (_lastLayout != store.episodeLayout) {
      _lastLayout = store.episodeLayout;
      revealCurrent();
    }
    var header = _header(store);
    var divider = Container(height: 1, color: BTColors.divider(context));
    var content = Expanded(
      child: _showHistory ? _history(store) : _playlist(store),
    );
    // 选集浮出层的标题、排版切换和刷新靠近控制栏；侧栏与记录页保持顶部。
    var headerAtBottom = widget.section == _PlaybackLibrarySection.playlist;
    return Container(
      decoration: BoxDecoration(
        color: BTColors.surfaceSecondary(context),
        borderRadius: BTRadius.largeBR,
        border: Border.all(
          width: _borderWidth,
          color: BTColors.divider(context),
        ),
      ),
      child: Column(
        children: headerAtBottom
            ? [content, divider, header]
            : [header, divider, content],
      ),
    );
  }

  Widget _header(PlaybackStore store) => Padding(
    padding: const EdgeInsets.all(6),
    child: LayoutBuilder(
      builder: (context, constraints) {
        // 窄浮出层优先保留入口，排版切换在宽度足够时才出现。
        var showLayout =
            !_showHistory &&
            store.playlist.isNotEmpty &&
            constraints.maxWidth >= 220;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                if (!_showHistory) ...[
                  _autoMarkToggle(store),
                  const SizedBox(width: 6),
                ],
                if (widget.section == null) ...[
                  _tab('选集', false, store.playlist.length),
                  const SizedBox(width: 4),
                  _tab('记录', true, store.historyGroups.length),
                ] else
                  Expanded(child: _sectionTitle(store)),
                if (showLayout) ...[
                  const SizedBox(width: 4),
                  _layoutSwitch(store),
                ],
                Tooltip(
                  message: '刷新',
                  child: IconButton(
                    icon: const Icon(FluentIcons.refresh, size: 14),
                    onPressed: !_showHistory && !store.canRefresh
                        ? null
                        : () => widget.run(() async {
                            if (_showHistory) {
                              _resolvedHistorySubjects.clear();
                              await store.refreshHistory();
                            } else {
                              await store.refresh();
                              if (!mounted) return;
                              await ref
                                  .read(episodeMarkProvider.notifier)
                                  .syncItems(store.playlist, refresh: true);
                            }
                          }),
                  ),
                ),
              ],
            ),
            if (_showHistory || store.isOpening)
              SizedBox(
                height: _secondaryHeaderHeight,
                child: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      if (_showHistory)
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 200),
                              child: _historySearchBox(),
                            ),
                          ),
                        )
                      else
                        const Spacer(),
                      if (store.openingStatus case var status?)
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: constraints.maxWidth / 2,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Tooltip(
                              message: status,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const SizedBox.square(
                                    dimension: 16,
                                    child: ProgressRing(strokeWidth: 2),
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      status,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: BTTypography.caption(context),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    ),
  );

  Widget _autoMarkToggle(PlaybackStore store) {
    var progress = ref.watch(episodeMarkProvider);
    var reason = _savingAutoMark
        ? '正在保存设置…'
        : store.isOpening
        ? '正在切换视频…'
        : progress.autoMarkDisabledReason(store.current);
    return Tooltip(
      message:
          '播放完自动标记完成\n'
          '${reason ?? '自然播放结束后标记当前章节看过，不影响自动切集'}',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            FluentIcons.completed,
            size: 14,
            color: reason != null ? BTColors.textTertiary(context) : null,
          ),
          const SizedBox(width: 6),
          Semantics(
            label: '播放完自动标记完成',
            child: ToggleSwitch(
              checked: store.autoMarkWatched,
              onChanged: reason != null
                  ? null
                  : (enabled) async {
                      setState(() => _savingAutoMark = true);
                      try {
                        await widget.run(
                          () => store.setAutoMarkWatched(enabled),
                        );
                      } finally {
                        if (mounted) {
                          setState(() => _savingAutoMark = false);
                        }
                      }
                    },
            ),
          ),
        ],
      ),
    );
  }

  Widget _historySearchBox() => TextBox(
    controller: _historySearch,
    placeholder: '搜索记录',
    style: BTTypography.caption(context),
    prefix: const Padding(
      padding: EdgeInsets.only(left: 8),
      child: Icon(FluentIcons.search, size: 14),
    ),
    suffix: _historySearch.text.isEmpty
        ? null
        : Tooltip(
            message: '清空搜索',
            child: IconButton(
              icon: const Icon(FluentIcons.clear, size: 12),
              onPressed: () {
                _historySearch.clear();
                _searchHistory('');
              },
            ),
          ),
    onChanged: _searchHistory,
  );

  void _searchHistory(String value) {
    var query = value.trim().toLowerCase();
    var hydrateNames = _historyQuery.isEmpty && query.isNotEmpty;
    setState(() => _historyQuery = query);
    if (_historyScroll.hasClients) _historyScroll.jumpTo(0);
    if (hydrateNames) {
      var store = ref.read(playbackStoreProvider);
      unawaited(
        widget.run(
          () => store.hydrateCovers(
            store.historyGroups.map((group) => group.subject).whereType<int>(),
          ),
        ),
      );
    }
  }

  /// 单一内容的浮出层标题，替代侧栏里的两个标签页。
  Widget _sectionTitle(PlaybackStore store) => Container(
    height: 32,
    alignment: Alignment.centerLeft,
    padding: const EdgeInsets.symmetric(horizontal: 6),
    child: Text(
      _showHistory
          ? '播放记录 ${store.historyGroups.length}'
          : '选集 ${store.playlist.length}',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: BTTypography.caption(context).copyWith(
        color: BTColors.textSecondary(context),
        fontWeight: FontWeight.w600,
      ),
    ),
  );

  /// 选集与列表两种排版共用一个两段式切换，当前项用强调色标记。
  Widget _layoutSwitch(PlaybackStore store) {
    var accent = FluentTheme.of(context).accentColor;
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: BTColors.surfaceTertiary(context),
        borderRadius: BTRadius.smallBR,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var layout in PlaybackEpisodeLayout.values)
            _layoutOption(store, layout, accent),
        ],
      ),
    );
  }

  Widget _layoutOption(
    PlaybackStore store,
    PlaybackEpisodeLayout layout,
    Color accent,
  ) {
    var selected = store.episodeLayout == layout;
    return Tooltip(
      message: selected
          ? '${layout.label}布局 · ${layout.description}'
          : '切换为${layout.label}布局',
      child: HoverButton(
        semanticLabel: '${layout.label}布局',
        onPressed: selected
            ? null
            : () => unawaited(widget.run(() => store.setEpisodeLayout(layout))),
        builder: (context, states) => Container(
          width: 26,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? accent.withValues(alpha: 0.16)
                : states.isHovered
                ? BTColors.surfacePrimary(context)
                : Colors.transparent,
            borderRadius: BTRadius.smallBR,
          ),
          child: Icon(
            _playbackLayoutIcon(layout),
            size: 14,
            color: selected ? accent : BTColors.textSecondary(context),
          ),
        ),
      ),
    );
  }

  Widget _tab(String title, bool history, int count) => Expanded(
    child: HoverButton(
      semanticLabel: '$title $count',
      onPressed: () {
        setState(() => _showHistory = history);
        if (!history) revealCurrent();
      },
      builder: (context, states) {
        var selected = _showHistory == history;
        var accent = FluentTheme.of(context).accentColor;
        return Container(
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? accent.withValues(alpha: 0.12)
                : states.isHovered
                ? BTColors.surfaceTertiary(context)
                : Colors.transparent,
            borderRadius: BTRadius.mediumBR,
          ),
          child: Text(
            '$title $count',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: BTTypography.caption(context).copyWith(
              color: selected ? accent : BTColors.textSecondary(context),
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        );
      },
    ),
  );

  Widget _playlist(PlaybackStore store) {
    if (store.playlist.isEmpty) return _empty('暂无播放列表');
    return LayoutBuilder(
      builder: (context, constraints) {
        var columns = _columnsFor(constraints.maxWidth);
        if (_columns != columns) {
          _columns = columns;
          revealCurrent();
        }
        return FlyoutTarget(
          controller: _menu,
          child: store.episodeLayout == PlaybackEpisodeLayout.list
              ? Scrollbar(
                  controller: _listScroll,
                  child: ListView.builder(
                    controller: _listScroll,
                    padding: const EdgeInsets.all(_listPadding),
                    itemCount: store.playlist.length,
                    itemBuilder: (_, index) => _episodeRow(store, index),
                  ),
                )
              : Scrollbar(
                  controller: _gridScroll,
                  child: GridView.builder(
                    controller: _gridScroll,
                    padding: const EdgeInsets.all(_gridPadding),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      mainAxisExtent: _cellHeight,
                      mainAxisSpacing: _gap,
                      crossAxisSpacing: _gap,
                    ),
                    itemCount: store.playlist.length,
                    itemBuilder: (_, index) => _episodeCell(store, index),
                  ),
                ),
        );
      },
    );
  }

  /// 列表排版每行显示文件名、画质与文件大小，集数固定在行首。
  Widget _episodeRow(PlaybackStore store, int index) {
    var item = store.playlist[index];
    var selected = store.index == index;
    var label = ref.watch(playbackLabelProvider(item));
    var number = label.episodeNumber ?? '—';
    var accent = FluentTheme.of(context).accentColor;
    var meta = [
      if (item.sizeBytes != null) filesize(item.sizeBytes!),
      if (label.episode != null) label.episode!,
      if (label.details.isNotEmpty) label.details,
    ].join(' · ');
    return Tooltip(
      message: item.title,
      child: GestureDetector(
        onSecondaryTapUp: (details) =>
            _showItemMenu(item, details.globalPosition),
        child: HoverButton(
          key: ValueKey((item.subject, item.key)),
          semanticLabel: '第 $number 集',
          onPressed: () {
            if (!store.loading && !store.isOpening && !selected) {
              unawaited(widget.run(() => store.jump(index)));
            }
          },
          builder: (context, states) {
            var reveal = states.isHovered || selected;
            return Container(
              height: _rowHeight,
              margin: const EdgeInsets.only(bottom: _gap),
              padding: const EdgeInsets.fromLTRB(6, 0, 4, 0),
              decoration: BoxDecoration(
                color: selected
                    ? accent.withValues(alpha: 0.16)
                    : states.isHovered
                    ? BTColors.surfaceTertiary(context)
                    : BTColors.surfacePrimary(context),
                borderRadius: BTRadius.mediumBR,
                border: Border.all(
                  color: selected ? accent : BTColors.divider(context),
                ),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 28,
                    child: Text(
                      number,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: BTTypography.bodyStrong(context).copyWith(
                        color: selected
                            ? accent
                            : BTColors.textPrimary(context),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          label.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: BTTypography.caption(context).copyWith(
                            color: selected
                                ? accent
                                : BTColors.textPrimary(context),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (meta.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            meta,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: BTTypography.caption(context).copyWith(
                              fontSize: 11,
                              color: BTColors.textTertiary(context),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // 右键菜单里的操作在列表排版下作为纯图标常驻行尾。
                  _PlaybackRowAction(
                    icon: material.Icons.open_in_new_rounded,
                    tooltip: '用外部播放器打开',
                    reveal: reveal,
                    onPressed: () =>
                        widget.run(() => widget.openExternalPlayer(item)),
                  ),
                  _PlaybackRowAction(
                    icon: material.Icons.folder_open_rounded,
                    tooltip: '打开所在目录',
                    reveal: reveal,
                    onPressed: () =>
                        widget.run(() => widget.openVideoDirectory(item)),
                  ),
                  if (item.subject != null)
                    _PlaybackRowAction(
                      icon: material.Icons.info_outline_rounded,
                      tooltip: '查看章节',
                      reveal: reveal,
                      onPressed: () => widget.openSubject(item.subject!),
                    ),
                  PlaybackEpisodeMarkButton(
                    item: item,
                    compact: true,
                    reveal: reveal,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _episodeCell(PlaybackStore store, int index) {
    var item = store.playlist[index];
    var selected = store.index == index;
    var label = ref.watch(playbackLabelProvider(item));
    var number = label.episodeNumber;
    var accent = FluentTheme.of(context).accentColor;
    return Tooltip(
      message: item.title,
      child: GestureDetector(
        onSecondaryTapUp: (details) =>
            _showItemMenu(item, details.globalPosition),
        child: HoverButton(
          key: ValueKey((item.subject, item.key)),
          semanticLabel: number == null ? item.title : '第 $number 集',
          onPressed: () {
            if (!store.loading && !store.isOpening && !selected) {
              unawaited(widget.run(() => store.jump(index)));
            }
          },
          builder: (context, states) => Container(
            decoration: BoxDecoration(
              color: selected
                  ? accent.withValues(alpha: 0.16)
                  : states.isHovered
                  ? BTColors.surfaceTertiary(context)
                  : BTColors.surfacePrimary(context),
              borderRadius: BTRadius.mediumBR,
              border: Border.all(
                color: selected ? accent : BTColors.divider(context),
              ),
            ),
            child: Stack(
              children: [
                Center(
                  child: Text(
                    number ?? '视频',
                    style: BTTypography.bodyStrong(context).copyWith(
                      color: selected ? accent : BTColors.textPrimary(context),
                    ),
                  ),
                ),
                Positioned(
                  top: 1,
                  right: 1,
                  child: PlaybackEpisodeMarkButton(
                    item: item,
                    compact: true,
                    reveal: states.isHovered,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showItemMenu(PlaybackItem item, Offset globalPosition) {
    var navigator =
        Navigator.of(context).context.findRenderObject() as RenderBox;
    unawaited(
      widget.run(() async {
        await _menu.showFlyout<void>(
          position: navigator.globalToLocal(globalPosition),
          builder: (_) => MenuFlyout(
            items: [
              MenuFlyoutItem(
                text: const Text('用外部播放器打开'),
                onPressed: () =>
                    widget.run(() => widget.openExternalPlayer(item)),
              ),
              MenuFlyoutItem(
                text: const Text('打开所在目录'),
                onPressed: () =>
                    widget.run(() => widget.openVideoDirectory(item)),
              ),
              if (item.subject != null)
                MenuFlyoutItem(
                  text: const Text('查看章节'),
                  onPressed: () => widget.openSubject(item.subject!),
                ),
            ],
          ),
        );
      }),
    );
  }

  /// 播放动作也可补齐尚未载入的条目信息。
  void _resolveBeforePlayback(PlaybackStore store, int? subject) {
    if (subject == null) return;
    unawaited(store.resolveCover(subject));
  }

  Widget _history(PlaybackStore store) {
    if (store.historyGroups.isEmpty) return _empty('暂无播放记录');
    var groups = _historyQuery.isEmpty
        ? store.historyGroups
        : store.historyGroups.where((group) {
            var name = store.nameFor(group.subject);
            return (name?.toLowerCase().contains(_historyQuery) ?? false) ||
                group.items.any(
                  (item) =>
                      item.title.toLowerCase().contains(_historyQuery) ||
                      item.filePath.toLowerCase().contains(_historyQuery),
                );
          }).toList();
    if (groups.isEmpty) return _empty('没有匹配的播放记录');
    var slivers = <Widget>[];
    var collapsedStart = 0;
    // 折叠条目连续放在懒加载列表里，避免为吸顶表头预先解析整份历史。
    void addCollapsedRows(int end) {
      if (collapsedStart == end) return;
      var collapsedGroups = groups.sublist(collapsedStart, end);
      slivers.add(
        SliverList.builder(
          itemCount: collapsedGroups.length,
          itemBuilder: (_, index) => _historyRow(store, collapsedGroups[index]),
        ),
      );
    }

    for (var index = 0; index < groups.length; index++) {
      var group = groups[index];
      if (group.items.length <= 1 || !_expandedHistory.contains(group.key)) {
        continue;
      }
      addCollapsedRows(index);
      slivers.add(_expandedHistorySliver(store, group));
      collapsedStart = index + 1;
    }
    addCollapsedRows(groups.length);
    return Scrollbar(
      controller: _historyScroll,
      child: CustomScrollView(
        controller: _historyScroll,
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(6),
            sliver: SliverMainAxisGroup(slivers: slivers),
          ),
        ],
      ),
    );
  }

  void _resolveHistorySubject(PlaybackStore store, PlaybackHistoryGroup group) {
    var subject = group.subject;
    // 按实际构建的历史项加载名称和封面，优先命中本地数据。
    if (subject != null && _resolvedHistorySubjects.add(subject)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(
          store.resolveCover(subject).catchError((Object failure) {
            BTLogTool.warn('加载播放记录条目信息失败：$failure');
          }),
        );
      });
    }
  }

  Widget _historyRow(PlaybackStore store, PlaybackHistoryGroup group) {
    _resolveHistorySubject(store, group);
    return Container(
      margin: const EdgeInsets.only(bottom: _gap),
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: BTColors.surfacePrimary(context),
        borderRadius: BTRadius.largeBR,
        border: Border.all(color: BTColors.divider(context)),
      ),
      child: _historySummary(store, group, false),
    );
  }

  Widget _expandedHistorySliver(
    PlaybackStore store,
    PlaybackHistoryGroup group,
  ) {
    _resolveHistorySubject(store, group);
    var surface = BTColors.surfacePrimary(context);
    var border = BorderSide(color: BTColors.divider(context));
    return SliverPadding(
      key: ValueKey(group.key),
      padding: const EdgeInsets.only(bottom: _gap),
      sliver: DecoratedSliver(
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BTRadius.largeBR,
          border: Border.fromBorderSide(border),
        ),
        // 表头只在自己的记录范围内吸顶，下一条目进入时将它顶出。
        sliver: SliverMainAxisGroup(
          slivers: [
            PinnedHeaderSliver(
              child: ColoredBox(
                // 填满圆角外侧，遮住从吸顶表头下方滚过的记录。
                color: BTColors.surfaceSecondary(context),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(2, 2, 2, 0),
                  decoration: BoxDecoration(
                    color: surface,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(BTRadius.large),
                    ),
                    border: Border(top: border, left: border, right: border),
                  ),
                  child: _historySummary(store, group, true),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(3, 0, 3, 3),
              sliver: SliverList.builder(
                itemCount: group.items.length,
                itemBuilder: (_, index) =>
                    _historyEpisode(store, group.items[index]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _historyEpisode(PlaybackStore store, PlaybackItem item) {
    var label = ref.watch(playbackLabelProvider(item));
    var progress = item.completed
        ? '已播完'
        : '${_PlaybackPageState._time(item.positionMs)} / '
              '${_PlaybackPageState._time(item.durationMs)}';
    var date = DateTime.fromMillisecondsSinceEpoch(item.updatedAt);
    var stamp =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.only(left: 12, right: 4, bottom: 4),
      child: Tooltip(
        message: item.filePath,
        child: HoverButton(
          key: ValueKey('history:${item.key}'),
          onPressed: store.isOpening
              ? null
              : () {
                  _resolveBeforePlayback(store, item.subject);
                  unawaited(resumeLocalPlayback(context, ref, item));
                },
          builder: (context, states) => Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: states.isHovered
                  ? BTColors.surfaceTertiary(context)
                  : BTColors.surfaceSecondary(context),
              borderRadius: BTRadius.mediumBR,
            ),
            child: Row(
              children: [
                const Icon(material.Icons.play_arrow_rounded, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label.episode ?? item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: BTTypography.body(context),
                      ),
                      Text(
                        '$progress · $stamp',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: BTTypography.caption(context),
                      ),
                    ],
                  ),
                ),
                Tooltip(
                  message: '删除此播放记录',
                  child: IconButton(
                    icon: const Icon(FluentIcons.delete, size: 14),
                    onPressed: () =>
                        widget.run(() => store.removeHistory(item.filePath)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _historySummary(
    PlaybackStore store,
    PlaybackHistoryGroup group,
    bool expanded,
  ) {
    var item = group.latest;
    var label = ref.watch(playbackLabelProvider(item));
    return Tooltip(
      message: '${item.filePath}\n${group.items.length} 条播放记录',
      child: HoverButton(
        key: ValueKey(group.key),
        onPressed: store.isOpening
            ? null
            : () {
                _resolveBeforePlayback(store, group.subject);
                unawaited(resumeLocalPlayback(context, ref, item));
              },
        builder: (context, states) => Container(
          padding: const EdgeInsets.fromLTRB(8, 8, 4, 8),
          decoration: BoxDecoration(
            color: states.isHovered
                ? BTColors.surfaceTertiary(context)
                : Colors.transparent,
            borderRadius: BTRadius.mediumBR,
          ),
          child: Row(
            children: [
              SizedBox(
                width: 36,
                height: 50,
                child: ClipRRect(
                  borderRadius: BTRadius.smallBR,
                  child: BtBangumiCover(
                    imageUrl: store.coverFor(group.subject),
                    maxRequestEdge: BangumiCoverUrl.thumbMaxEdge,
                    progressSize: 16,
                    errorBuilder: (context, {err}) => ColoredBox(
                      color: BTColors.surfaceTertiary(context),
                      child: Center(
                        child: Icon(
                          FluentIcons.media,
                          size: 18,
                          color: BTColors.textTertiary(context),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      store.nameFor(group.subject) ?? label.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: BTTypography.bodyStrong(context),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        if (label.episodeNumber != null)
                          '第 ${label.episodeNumber} 集',
                        item.completed
                            ? '已播完'
                            : _PlaybackPageState._time(item.positionMs),
                        if (group.items.length > 1) '${group.items.length} 条记录',
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: BTTypography.caption(context),
                    ),
                  ],
                ),
              ),
              if (group.items.length > 1)
                Tooltip(
                  message: expanded ? '收起播放记录列表' : '展开播放记录列表',
                  child: IconButton(
                    icon: Icon(
                      expanded
                          ? material.Icons.expand_less_rounded
                          : material.Icons.list_rounded,
                      size: 16,
                    ),
                    onPressed: () => setState(() {
                      if (expanded) {
                        _expandedHistory.remove(group.key);
                      } else {
                        _expandedHistory.add(group.key);
                      }
                    }),
                  ),
                ),
              if (group.subject != null)
                Tooltip(
                  message: '查看条目',
                  child: IconButton(
                    icon: const Icon(FluentIcons.info, size: 14),
                    onPressed: () => widget.openSubject(group.subject!),
                  ),
                ),
              Tooltip(
                message: '删除此条目的全部播放记录',
                child: IconButton(
                  icon: const Icon(FluentIcons.delete, size: 14),
                  onPressed: () =>
                      widget.run(() => store.removeHistoryGroup(group.key)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _empty(String text) =>
      Center(child: Text(text, style: BTTypography.caption(context)));
}

IconData _playbackLayoutIcon(PlaybackEpisodeLayout layout) => switch (layout) {
  PlaybackEpisodeLayout.grid => material.Icons.grid_view_rounded,
  PlaybackEpisodeLayout.list => material.Icons.view_list_rounded,
};

/// 播放控制浮出层的最大高度；内容超过后由内部列表滚动。
const _playbackFlyoutMaxHeight = 420.0;

/// `FlyoutContent` 的 1px 描边在内容外再占两像素。
const _playbackFlyoutBorder = 2.0;

/// 空态面板优先在按钮右侧居中；控制栏面板优先在上方，尺寸受可用空间限制。
/// 返回内容盒的尺寸与按钮侧；控制栏面板可以在盒内按自身内容贴边显示。
({Offset position, Size size, bool above}) _playbackLibraryFlyoutLayout({
  required BuildContext buttonContext,
  required RenderBox navigatorBox,
  bool besideButton = false,
  bool preferBelow = false,
  double maximumWidth = 360,
}) {
  const margin = 8.0;
  const gap = 8.0;
  var buttonBox = buttonContext.findRenderObject() as RenderBox;
  var topLeft = buttonBox.localToGlobal(Offset.zero, ancestor: navigatorBox);
  var button = topLeft & buttonBox.size;
  var bounds = (Offset.zero & navigatorBox.size).deflate(margin);
  var width = bounds.width.clamp(0.0, maximumWidth);
  var height = bounds.height.clamp(0.0, _playbackFlyoutMaxHeight);
  var rightSpace = bounds.right - button.right - gap;
  if (besideButton && rightSpace >= 140) {
    width = width.clamp(0.0, rightSpace);
    return (
      position: Offset(
        button.right + gap,
        (button.center.dy - height / 2).clamp(
          bounds.top,
          bounds.bottom - height,
        ),
      ),
      size: Size(width, height),
      above: false,
    );
  }
  var above = (button.top - gap - bounds.top).clamp(0.0, bounds.height);
  var below = (bounds.bottom - button.bottom - gap).clamp(0.0, bounds.height);
  var showAbove = preferBelow
      ? below < height && above > below
      : above >= below;
  height = height.clamp(0.0, showAbove ? above : below);
  return (
    position: Offset(
      (button.center.dx - width / 2).clamp(bounds.left, bounds.right - width),
      showAbove ? button.top - gap - height : button.bottom + gap,
    ),
    size: Size(width, height),
    above: showAbove,
  );
}

/// 控制栏浮出层：外层盒保持最大可用高度用于定位，面板按当前排版的实际
/// 高度贴边显示；切换排版后随内容重新计算，不需要重新打开浮出层。
Widget _playbackLibraryDynamicFlyout({
  required _PlaybackLibrarySection section,
  required Widget panel,
  required Size box,
  required bool above,
}) => SizedBox(
  width: box.width,
  height: box.height,
  child: Align(
    alignment: above ? Alignment.bottomCenter : Alignment.topCenter,
    child: DisableAcrylic(
      child: RepaintBoundary(
        child: _PlaybackLibraryFlyoutSurface(
          child: Consumer(
            child: panel,
            builder: (context, ref, child) {
              // Only count, layout and loading-row visibility affect height;
              // individual loading stages and metadata need no size rebuild.
              var (
                count,
                layout,
                isOpening,
              ) = section == _PlaybackLibrarySection.playlist
                  ? ref.watch(
                      playbackStoreProvider.select(
                        (store) => (
                          store.playlist.length,
                          store.episodeLayout,
                          store.isOpening,
                        ),
                      ),
                    )
                  : (0, PlaybackEpisodeLayout.grid, false);
              var panelWidth = box.width - _playbackFlyoutBorder;
              var maximumPanelHeight = (box.height - _playbackFlyoutBorder)
                  .clamp(0.0, double.infinity)
                  .toDouble();
              var panelHeight = section == _PlaybackLibrarySection.playlist
                  ? _PlaybackLibraryPanelState.playlistFlyoutHeight(
                      count: count,
                      layout: layout,
                      width: panelWidth,
                      isOpening: isOpening,
                    ).clamp(0.0, maximumPanelHeight).toDouble()
                  : maximumPanelHeight;
              return SizedBox(
                width: panelWidth,
                height: panelHeight,
                child: child,
              );
            },
          ),
        ),
      ),
    ),
  ),
);

Widget _playbackLibraryFlyout(Widget panel, Size size) => DisableAcrylic(
  // useAcrylic alone does not remove fluent_ui's BackdropFilter.
  child: RepaintBoundary(
    child: _PlaybackLibraryFlyoutSurface(
      child: SizedBox(width: size.width, height: size.height, child: panel),
    ),
  ),
);

/// Share one restrained shadow across the fixed and content-sized flyouts.
class _PlaybackLibraryFlyoutSurface extends StatelessWidget {
  const _PlaybackLibraryFlyoutSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.all(Radius.circular(8));
    var stroke = FluentTheme.of(context).resources.surfaceStrokeColorFlyout;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: BTTheme.shadow(context),
      ),
      child: FlyoutContent(
        padding: EdgeInsets.zero,
        useAcrylic: false,
        // Avoid the transparent PhysicalModel's broad elevation shadow.
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: stroke),
        ),
        child: child,
      ),
    );
  }
}

/// 列表行的行内操作：纯图标，与标记按钮一起在悬停或选中时出现。
class _PlaybackRowAction extends StatelessWidget {
  const _PlaybackRowAction({
    required this.icon,
    required this.tooltip,
    required this.reveal,
    this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final bool reveal;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    ignoring: !reveal,
    child: Opacity(
      opacity: reveal ? 1 : 0,
      child: Tooltip(
        message: tooltip,
        child: IconButton(
          style: ButtonStyle(
            padding: WidgetStateProperty.all(const EdgeInsets.all(2)),
          ),
          icon: Icon(icon, size: 14, color: BTColors.textSecondary(context)),
          onPressed: onPressed,
        ),
      ),
    ),
  );
}
