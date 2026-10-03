// Dart imports:
import 'dart:async';

// Package imports:
import 'package:file_selector/file_selector.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

// Project imports:
import '../../core/theme/bt_theme.dart';
import '../../models/playback/playback_item.dart';
import '../../store/nav_store.dart';
import '../../store/playback_store.dart';
import '../../ui/bt_infobar.dart';
import 'playback_actions.dart';
import 'playback_label.dart';

part 'playback_controls.dart';

class PlaybackPage extends ConsumerStatefulWidget {
  const PlaybackPage({super.key});

  @override
  ConsumerState<PlaybackPage> createState() => _PlaybackPageState();
}

class _PlaybackPageState extends ConsumerState<PlaybackPage> {
  late final PlaybackStore _store;
  late final BTNavStore _nav;
  final _playlistScroll = ScrollController();
  final _historyScroll = ScrollController();
  final _videoKey = GlobalKey<VideoState>();
  bool _wasActive = true;
  bool _sidebarVisible = true;
  bool _showHistory = false;
  String? _lastPlayingKey;
  int _lastPlayingIndex = -1;
  static const _playlistRowHeight = 48.0;

  @override
  void initState() {
    super.initState();
    _store = ref.read(playbackStoreProvider);
    _nav = ref.read(navStoreProvider);
    _showHistory = _store.playlist.isEmpty;
    _wasActive = _nav.curIndex == _nav.playbackIndex;
    _nav.addListener(_onNavigation);
    _store.beforeVideoDispose = _exitVideoFullscreen;
    _onPlaybackChanged();
    unawaited(_run(_store.refreshHistory));
  }

  void _onNavigation() {
    var active = _nav.curIndex == _nav.playbackIndex;
    if (_wasActive && !active) unawaited(_run(_store.pause));
    _wasActive = active;
  }

  void _onPlaybackChanged() {
    var key = _store.current?.key;
    if (key == _lastPlayingKey && _store.index == _lastPlayingIndex) return;
    if (key != null && _lastPlayingKey == null) _showHistory = false;
    if (key == null && _lastPlayingKey != null) _showHistory = true;
    _lastPlayingKey = key;
    _lastPlayingIndex = _store.index;
    _revealCurrent();
  }

  void _revealCurrent() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_playlistScroll.hasClients || _store.index < 0) return;
      var position = _playlistScroll.position;
      var top = 8 + _store.index * _playlistRowHeight;
      if (top >= position.pixels &&
          top + _playlistRowHeight <=
              position.pixels + position.viewportDimension) {
        return;
      }
      unawaited(
        _playlistScroll.animateTo(
          (top - position.viewportDimension / 2 + _playlistRowHeight / 2).clamp(
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
  void dispose() {
    _nav.removeListener(_onNavigation);
    if (_store.beforeVideoDispose == _exitVideoFullscreen) {
      _store.beforeVideoDispose = null;
    }
    _playlistScroll.dispose();
    _historyScroll.dispose();
    unawaited(_store.pause().catchError((Object _) {}));
    super.dispose();
  }

  Future<void> _exitVideoFullscreen() async {
    var video = _videoKey.currentState;
    if (video != null && video.isFullscreen()) await video.exitFullscreen();
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      if (mounted) await BtInfobar.error(context, error.toString());
    }
  }

  Future<void> _pickFile() async {
    var file = await openFile(
      acceptedTypeGroups: [
        const XTypeGroup(
          label: '视频',
          extensions: [
            'mp4',
            'mkv',
            'avi',
            'mov',
            'webm',
            'm4v',
            'ts',
            'm2ts',
            'wmv',
            'flv',
            'mpg',
            'mpeg',
            'ogv',
          ],
        ),
      ],
    );
    if (file != null && mounted) {
      await openLocalPlayback(context, ref, file.path);
    }
  }

  Future<void> _pickSubtitle() async {
    var file = await openFile(
      acceptedTypeGroups: [
        const XTypeGroup(
          label: '字幕',
          extensions: ['ass', 'ssa', 'srt', 'vtt', 'sub'],
        ),
      ],
    );
    if (file != null) {
      await _store.player?.setSubtitleTrack(SubtitleTrack.uri(file.path));
    }
  }

  @override
  Widget build(BuildContext context) {
    var store = ref.watch(playbackStoreProvider);
    _onPlaybackChanged();
    return ScaffoldPage(
      padding: EdgeInsets.zero,
      content: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          children: [
            _buildHeader(store),
            const SizedBox(height: 16),
            if (store.error != null) ...[
              InfoBar(
                title: const Text('无法播放'),
                content: Text(store.error!),
                severity: InfoBarSeverity.error,
              ),
              const SizedBox(height: 12),
            ],
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  var stage = _buildStage(store);
                  if (!_sidebarVisible) return stage;
                  var sidebar = _buildSidebar(store);
                  if (constraints.maxWidth < 900) {
                    return Column(
                      children: [
                        Expanded(child: stage),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: (constraints.maxHeight * 0.34).clamp(
                            140.0,
                            240.0,
                          ),
                          child: sidebar,
                        ),
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: stage),
                      const SizedBox(width: 16),
                      SizedBox(width: 280, child: sidebar),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(PlaybackStore store) {
    var current = store.current;
    var label = current == null ? null : PlaybackLabel.fromName(current.title);
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: FluentTheme.of(
                context,
              ).accentColor.withValues(alpha: 0.12),
              borderRadius: BTRadius.mediumBR,
            ),
            child: Icon(
              FluentIcons.play,
              size: 18,
              color: FluentTheme.of(context).accentColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label == null
                      ? '本地播放器'
                      : [
                          '当前播放',
                          if (label.episode != null) label.episode!,
                        ].join(' · '),
                  style: BTTypography.caption(context),
                ),
                const SizedBox(height: 3),
                Tooltip(
                  message: current?.title ?? '从下载或 BMF 打开视频',
                  child: Text(
                    label?.title ?? '播放',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: BTTypography.subtitle(context),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Tooltip(
            message: '打开本地视频',
            child: IconButton(
              icon: const Icon(FluentIcons.open_file, size: 18),
              onPressed: () => _run(_pickFile),
            ),
          ),
          if (current != null)
            Tooltip(
              message: '停止播放',
              child: IconButton(
                icon: const Icon(FluentIcons.stop, size: 18),
                onPressed: () => _run(store.stop),
              ),
            ),
          const SizedBox(width: 4),
          Tooltip(
            message: _sidebarVisible ? '收起播放侧栏' : '展开播放侧栏',
            child: IconButton(
              key: const ValueKey('playback-sidebar-toggle'),
              icon: Icon(
                material.Icons.view_sidebar_outlined,
                size: 19,
                color: _sidebarVisible
                    ? FluentTheme.of(context).accentColor
                    : BTColors.textSecondary(context),
              ),
              onPressed: () {
                setState(() => _sidebarVisible = !_sidebarVisible);
                if (_sidebarVisible && !_showHistory) _revealCurrent();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStage(PlaybackStore store) => ClipRRect(
    borderRadius: BTRadius.largeBR,
    child: ColoredBox(
      color: Colors.black,
      child: store.current == null || store.video == null
          ? _buildEmptyStage()
          : LayoutBuilder(
              builder: (context, constraints) => material.Theme(
                data: material.ThemeData.dark().copyWith(
                  colorScheme: material.ColorScheme.fromSeed(
                    seedColor: FluentTheme.of(context).accentColor,
                    brightness: material.Brightness.dark,
                  ),
                ),
                child: material.Material(
                  color: Colors.black,
                  child: MaterialDesktopVideoControlsTheme(
                    normal: _controlsTheme(store, constraints.maxWidth),
                    fullscreen: _controlsTheme(store, double.infinity),
                    child: Video(
                      key: _videoKey,
                      controller: store.video!,
                      controls: MaterialDesktopVideoControls,
                    ),
                  ),
                ),
              ),
            ),
    ),
  );

  Widget _buildEmptyStage() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            material.Icons.play_circle_outline_rounded,
            color: Colors.white.withValues(alpha: 0.35),
            size: 64,
          ),
          const SizedBox(height: 18),
          const Text(
            '选择视频，开始观看',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            '从 BMF、已完成下载或最近播放中打开',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () => _run(_pickFile),
            child: const Text('打开本地视频'),
          ),
        ],
      ),
    ),
  );

  Widget _buildSidebar(PlaybackStore store) {
    var labels = store.playlist
        .map((item) => PlaybackLabel.fromName(item.title))
        .toList();
    var sameSeries =
        labels.isNotEmpty &&
        labels.every((label) => label.title == labels.first.title);
    return Container(
      decoration: BoxDecoration(
        color: BTColors.surfaceSecondary(context),
        borderRadius: BTRadius.largeBR,
        border: Border.all(color: BTColors.divider(context)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                _sidebarTab('播放列表', false, store.playlist.length),
                const SizedBox(width: 4),
                _sidebarTab('最近播放', true, store.history.length),
              ],
            ),
          ),
          Container(height: 1, color: BTColors.divider(context)),
          Expanded(
            child: _showHistory
                ? _buildHistory(store)
                : store.playlist.isEmpty
                ? _sidebarEmpty(material.Icons.playlist_play, '暂无播放列表')
                : Scrollbar(
                    controller: _playlistScroll,
                    child: ListView.builder(
                      key: const PageStorageKey('playback-playlist'),
                      controller: _playlistScroll,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemExtent: _playlistRowHeight,
                      itemCount: store.playlist.length,
                      itemBuilder: (_, index) =>
                          _playlistRow(store, index, labels[index], sameSeries),
                    ),
                  ),
          ),
          if (!_showHistory && store.playlist.isNotEmpty) ...[
            Container(height: 1, color: BTColors.divider(context)),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 8, 4),
              child: Row(
                children: [
                  Text(
                    '${store.playlist.length} 个视频 · 自动连播',
                    style: BTTypography.caption(context),
                  ),
                  const Spacer(),
                  Tooltip(
                    message: '定位当前视频',
                    child: IconButton(
                      icon: const Icon(material.Icons.my_location, size: 16),
                      onPressed: _revealCurrent,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _sidebarTab(String title, bool history, int count) => Expanded(
    child: HoverButton(
      semanticLabel: title,
      onPressed: () {
        setState(() => _showHistory = history);
        if (!history) _revealCurrent();
      },
      builder: (context, states) {
        var selected = _showHistory == history;
        var accent = FluentTheme.of(context).accentColor;
        return Container(
          height: 34,
          decoration: BoxDecoration(
            color: selected
                ? accent.withValues(alpha: 0.12)
                : states.isHovered
                ? BTColors.surfaceTertiary(context)
                : Colors.transparent,
            borderRadius: BTRadius.mediumBR,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected ? accent : BTColors.textSecondary(context),
                ),
              ),
              const SizedBox(width: 6),
              Text('$count', style: BTTypography.caption(context)),
            ],
          ),
        );
      },
    ),
  );

  Widget _playlistRow(
    PlaybackStore store,
    int index,
    PlaybackLabel label,
    bool sameSeries,
  ) {
    var selected = store.index == index;
    var accent = FluentTheme.of(context).accentColor;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      child: Tooltip(
        message: store.playlist[index].title,
        child: HoverButton(
          key: ValueKey('playback-item-$index'),
          onPressed: store.loading ? null : () => _run(() => store.jump(index)),
          builder: (context, states) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: selected
                  ? accent.withValues(alpha: 0.12)
                  : states.isHovered
                  ? BTColors.surfaceTertiary(context)
                  : Colors.transparent,
              borderRadius: BTRadius.mediumBR,
              border: Border.all(
                color: selected
                    ? accent.withValues(alpha: 0.3)
                    : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 22,
                  child: selected
                      ? Icon(FluentIcons.play, size: 12, color: accent)
                      : Text(
                          '${index + 1}'.padLeft(2, '0'),
                          style: BTTypography.caption(context),
                        ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sameSeries ? label.episode ?? label.title : label.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: BTTypography.body(context).copyWith(
                          height: 1.2,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: selected
                              ? accent
                              : BTColors.textPrimary(context),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        [
                          if (!sameSeries && label.episode != null)
                            label.episode!,
                          if (label.details.isNotEmpty) label.details,
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: BTTypography.caption(
                          context,
                        ).copyWith(height: 1.2),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHistory(PlaybackStore store) => store.history.isEmpty
      ? _sidebarEmpty(material.Icons.history, '暂无播放记录')
      : Scrollbar(
          controller: _historyScroll,
          child: ListView.builder(
            key: const PageStorageKey('playback-history'),
            controller: _historyScroll,
            padding: const EdgeInsets.all(8),
            itemCount: store.history.length,
            itemBuilder: (_, index) => _historyRow(store.history[index]),
          ),
        );

  Widget _historyRow(PlaybackItem item) {
    var label = PlaybackLabel.fromName(item.title);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Tooltip(
        message: item.filePath,
        child: HoverButton(
          onPressed: () => resumeLocalPlayback(context, ref, item),
          builder: (context, states) => Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
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
                        label.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: BTTypography.bodyStrong(context),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        [
                          if (label.episode != null) label.episode!,
                          item.completed
                              ? '已看完 · 点击重播'
                              : '${_time(item.positionMs)} / ${_time(item.durationMs)}',
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: BTTypography.caption(context),
                      ),
                      const SizedBox(height: 7),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: SizedBox(
                          height: 2,
                          child: Stack(
                            children: [
                              ColoredBox(
                                color: BTColors.divider(context),
                                child: const SizedBox.expand(),
                              ),
                              FractionallySizedBox(
                                widthFactor: item.completed
                                    ? 1
                                    : item.durationMs > 0
                                    ? (item.positionMs / item.durationMs).clamp(
                                        0.0,
                                        1.0,
                                      )
                                    : 0,
                                child: ColoredBox(
                                  color: FluentTheme.of(context).accentColor,
                                  child: const SizedBox.expand(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Tooltip(
                  message: '移除记录',
                  child: IconButton(
                    icon: const Icon(FluentIcons.delete, size: 14),
                    onPressed: () =>
                        _run(() => _store.removeHistory(item.filePath)),
                  ),
                ),
                if (item.subject != null)
                  Tooltip(
                    message: '查看条目',
                    child: IconButton(
                      icon: const Icon(FluentIcons.info, size: 14),
                      onPressed: () => ref
                          .read(navStoreProvider)
                          .addNavItemB(subject: item.subject!),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sidebarEmpty(IconData icon, String text) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 32, color: BTColors.textTertiary(context)),
        const SizedBox(height: 12),
        Text(text, style: BTTypography.caption(context)),
      ],
    ),
  );

  static String _time(int milliseconds) {
    var seconds = milliseconds ~/ 1000;
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }
}
