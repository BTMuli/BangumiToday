part of 'playback_page.dart';

/// Each sidebar/flyout owns its scrolling and tab state. The fullscreen route
/// can therefore open the same compact library without sharing scroll clients.
class _PlaybackLibraryPanel extends ConsumerStatefulWidget {
  const _PlaybackLibraryPanel({
    super.key,
    required this.run,
    required this.openExternalPlayer,
    required this.openVideoDirectory,
    required this.openSubject,
  });

  final Future<void> Function(Future<void> Function()) run;
  final Future<void> Function(PlaybackItem) openExternalPlayer;
  final Future<void> Function(PlaybackItem) openVideoDirectory;
  final Future<void> Function(int) openSubject;

  @override
  ConsumerState<_PlaybackLibraryPanel> createState() =>
      _PlaybackLibraryPanelState();
}

class _PlaybackLibraryPanelState extends ConsumerState<_PlaybackLibraryPanel> {
  final _playlistScroll = ScrollController();
  final _historyScroll = ScrollController();
  final _menu = FlyoutController();
  late bool _showHistory;
  String? _lastPlayingKey;
  int _lastIndex = -1;
  int _columns = 4;
  (String?, String)? _progressSignature;
  static const _cellHeight = 48.0;
  static const _gap = 6.0;

  @override
  void initState() {
    super.initState();
    var store = ref.read(playbackStoreProvider);
    _showHistory = store.playlist.isEmpty;
    _lastPlayingKey = store.current?.key;
    revealCurrent();
  }

  @override
  void dispose() {
    _playlistScroll.dispose();
    _historyScroll.dispose();
    _menu.dispose();
    super.dispose();
  }

  void revealCurrent() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _showHistory || !_playlistScroll.hasClients) return;
      var index = ref.read(playbackStoreProvider).index;
      if (index < 0) return;
      var position = _playlistScroll.position;
      var top = 8 + (index ~/ _columns) * (_cellHeight + _gap);
      if (top >= position.pixels &&
          top + _cellHeight <= position.pixels + position.viewportDimension) {
        return;
      }
      unawaited(
        _playlistScroll.animateTo(
          (top - position.viewportDimension / 2 + _cellHeight / 2).clamp(
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
      if (key != null && _lastPlayingKey == null) _showHistory = false;
      if (key == null && _lastPlayingKey != null) _showHistory = true;
      _lastPlayingKey = key;
      _lastIndex = store.index;
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
            child: Row(
              children: [
                _tab('选集', false, store.playlist.length),
                const SizedBox(width: 4),
                _tab('记录', true, store.historyGroups.length),
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
            ),
          ),
          Container(height: 1, color: BTColors.divider(context)),
          Expanded(child: _showHistory ? _history(store) : _playlist(store)),
        ],
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
          child: Scrollbar(
            controller: _playlistScroll,
            child: GridView.builder(
              controller: _playlistScroll,
              padding: const EdgeInsets.all(8),
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

  Widget _episodeCell(PlaybackStore store, int index) {
    var item = store.playlist[index];
    var selected = store.index == index;
    var number =
        PlaybackLabel.fromName(item.title).episodeNumber ?? '${index + 1}';
    var accent = FluentTheme.of(context).accentColor;
    return Tooltip(
      message: item.title,
      child: GestureDetector(
        onSecondaryTapUp: (details) =>
            _showItemMenu(item, details.globalPosition),
        child: HoverButton(
          key: ValueKey((item.subject, item.key)),
          semanticLabel: '第 $number 集',
          onPressed: () {
            if (!store.loading && !selected) {
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
                    number,
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
    var item = group.latest;
    var label = PlaybackLabel.fromName(item.title);
    if (group.subject != null) unawaited(store.resolveCover(group.subject!));
    return Tooltip(
      message: '${item.filePath}\n${group.items.length} 集播放记录',
      child: HoverButton(
        key: ValueKey(group.key),
        onPressed: () => resumeLocalPlayback(context, ref, item),
        builder: (context, states) => Container(
          margin: const EdgeInsets.only(bottom: 4),
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
                        if (group.items.length > 1) '${group.items.length} 集记录',
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: BTTypography.caption(context),
                    ),
                  ],
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
                message: '移除此条目的播放记录',
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
