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
  final _menu = FlyoutController();
  final _expandedHistory = <String>{};
  late bool _showHistory;
  String? _lastPlayingKey;
  int _lastIndex = -1;
  int _columns = 4;
  PlaybackEpisodeLayout? _lastLayout;
  (String?, String)? _progressSignature;
  static const _cellHeight = 48.0;
  static const _rowHeight = 46.0;
  static const _gap = 6.0;
  static const _gridPadding = 8.0;
  static const _listPadding = 6.0;

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
      unawaited(
        scroll.animateTo(
          (top - position.viewportDimension / 2 + height / 2).clamp(
            0.0,
            position.maxScrollExtent,
          ),
          duration: BTTheme.animationDurationNormal,
          curve: BTTheme.animationCurve,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    var store = ref.watch(playbackStoreProvider);
    var account = ref.watch(
      episodeMarkProvider.select((value) => value.account),
    );
    var signature = (
      account,
      store.playlist.map(EpisodeMarkState.itemKey).join('\n'),
    );
    if (_progressSignature != signature) {
      _progressSignature = signature;
      var items = List<PlaybackItem>.of(store.playlist);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _progressSignature != signature) return;
        unawaited(
          widget.run(
            () => ref.read(episodeMarkProvider.notifier).syncItems(items),
          ),
        );
      });
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
    return Container(
      decoration: BoxDecoration(
        color: BTColors.surfaceSecondary(context),
        borderRadius: BTRadius.largeBR,
        border: Border.all(color: BTColors.divider(context)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(6),
            child: LayoutBuilder(
              builder: (context, constraints) {
                // 窄浮出层优先保留入口，排版切换在宽度足够时才出现。
                var showLayout =
                    !_showHistory &&
                    store.playlist.isNotEmpty &&
                    constraints.maxWidth >= 220;
                return Row(
                  children: [
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
                );
              },
            ),
          ),
          Container(height: 1, color: BTColors.divider(context)),
          if (store.openingStatus case var status?)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  const SizedBox.square(
                    dimension: 16,
                    child: ProgressRing(strokeWidth: 2),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
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
          Expanded(child: _showHistory ? _history(store) : _playlist(store)),
        ],
      ),
    );
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
        var columns = ((constraints.maxWidth - 16 + _gap) / (56 + _gap))
            .floor()
            .clamp(1, 6);
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
    var label = PlaybackLabel.fromName(item.title, filePath: item.filePath);
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
    var label = PlaybackLabel.fromName(item.title, filePath: item.filePath);
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

  Widget _history(PlaybackStore store) {
    if (store.historyGroups.isEmpty) return _empty('暂无播放记录');
    return Scrollbar(
      controller: _historyScroll,
      child: ListView.builder(
        controller: _historyScroll,
        padding: const EdgeInsets.all(6),
        itemCount: store.historyGroups.length,
        itemBuilder: (_, index) =>
            _historyRow(store, store.historyGroups[index]),
      ),
    );
  }

  Widget _historyRow(PlaybackStore store, PlaybackHistoryGroup group) {
    var expanded =
        group.items.length > 1 && _expandedHistory.contains(group.key);
    return Container(
      margin: const EdgeInsets.only(bottom: _gap),
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: BTColors.surfacePrimary(context),
        borderRadius: BTRadius.largeBR,
        border: Border.all(color: BTColors.divider(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _historySummary(store, group, expanded),
          if (expanded)
            for (var item in group.items) _historyEpisode(store, item),
        ],
      ),
    );
  }

  Widget _historyEpisode(PlaybackStore store, PlaybackItem item) {
    var label = PlaybackLabel.fromName(item.title, filePath: item.filePath);
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
              : () => resumeLocalPlayback(context, ref, item),
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
    var label = PlaybackLabel.fromName(item.title, filePath: item.filePath);
    if (group.subject != null) unawaited(store.resolveCover(group.subject!));
    return Tooltip(
      message: '${item.filePath}\n${group.items.length} 条播放记录',
      child: HoverButton(
        key: ValueKey(group.key),
        onPressed: store.isOpening
            ? null
            : () => resumeLocalPlayback(context, ref, item),
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

/// 空态面板优先在按钮右侧居中；控制栏面板优先在上方，尺寸受可用空间限制。
({Offset position, Size size}) _playbackLibraryFlyoutLayout({
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
  var height = bounds.height.clamp(0.0, 420.0);
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
  );
}

Widget _playbackLibraryFlyout(Widget panel, Size size) => DisableAcrylic(
  // useAcrylic alone does not remove fluent_ui's BackdropFilter.
  child: FlyoutContent(
    padding: EdgeInsets.zero,
    useAcrylic: false,
    child: RepaintBoundary(
      child: SizedBox(width: size.width, height: size.height, child: panel),
    ),
  ),
);

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
