// Dart imports:
import 'dart:async';
import 'dart:io';

// Flutter imports:
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter/services.dart';

// Package imports:
import 'package:file_selector/file_selector.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:path/path.dart' as path;
import 'package:super_clipboard/super_clipboard.dart' as clipboard;
import 'package:url_launcher/url_launcher.dart';

// Project imports:
import '../../core/services/playback_library.dart';
import '../../core/theme/bt_theme.dart';
import '../../models/playback/playback_fit.dart';
import '../../models/playback/playback_item.dart';
import '../../models/playback/playback_rate.dart';
import '../../store/nav_store.dart';
import '../../store/playback_store.dart';
import '../../ui/bt_infobar.dart';
import '../../widgets/bangumi/bt_bangumi_cover.dart';
import 'playback_actions.dart';
import 'playback_label.dart';

part 'playback_controls.dart';
part 'playback_overlay.dart';
part 'playback_seek_bar.dart';
part 'playback_video_info.dart';

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
  final _overlay = _PlaybackOverlayController();
  bool _wasActive = true;
  bool _sidebarVisible = true;
  bool _showHistory = false;
  String? _lastPlayingKey;
  int _lastPlayingIndex = -1;
  int? _posterSubject;
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
    var subject = _store.current?.subject ?? _firstPlaylistSubject(_store);
    if (subject != null) _posterSubject = subject;
    _ensureCovers(_store);
    _revealCurrent();
  }

  int? _firstPlaylistSubject(PlaybackStore store) {
    for (var item in store.playlist) {
      if (item.subject != null) return item.subject;
    }
    return null;
  }

  void _ensureCovers(PlaybackStore store) {
    var subjects = <int>{};
    for (var item in store.playlist) {
      if (item.subject != null) subjects.add(item.subject!);
    }
    if (store.current?.subject != null) subjects.add(store.current!.subject!);
    if (_posterSubject != null) subjects.add(_posterSubject!);
    for (var subject in subjects) {
      unawaited(store.resolveCover(subject));
    }
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
    _overlay.dispose();
    unawaited(_store.pause().catchError((Object _) {}));
    super.dispose();
  }

  Future<void> _exitVideoFullscreen() async {
    if (_overlay.closeMenus()) await WidgetsBinding.instance.endOfFrame;
    var video = _videoKey.currentState;
    if (video != null && video.isFullscreen()) await video.exitFullscreen();
  }

  Future<void> _stopPlayback() async {
    await _exitVideoFullscreen();
    await _store.stop();
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

  Future<void> _openExternalPlayer(PlaybackItem item) async {
    await _store.library.ensureReady(item.filePath);
    if (!await launchUrl(
      Uri.file(item.filePath),
      mode: LaunchMode.externalApplication,
    )) {
      throw const PlaybackUnavailable('无法用系统默认播放器打开视频');
    }
  }

  Future<void> _openVideoDirectory(PlaybackItem item) async {
    var directory = path.dirname(item.filePath);
    if (!await Directory(directory).exists()) {
      throw const PlaybackUnavailable('视频所在目录不存在');
    }
    if (!await launchUrl(
      Uri.directory(directory),
      mode: LaunchMode.externalApplication,
    )) {
      throw const PlaybackUnavailable('无法打开视频所在目录');
    }
  }

  Future<void> _openSubject(int subject) async {
    await _run(() => _store.resolveCover(subject));
    if (!mounted) return;
    var name = _store.nameFor(subject);
    ref
        .read(navStoreProvider)
        .addNavItemB(
          subject: subject,
          paneTitle: (name == null || name.isEmpty) ? null : name,
        );
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
              icon: const Icon(FluentIcons.video, size: 18),
              onPressed: () => _run(_pickFile),
            ),
          ),
          if (current != null)
            Tooltip(
              message: '停止播放',
              child: IconButton(
                icon: const Icon(FluentIcons.stop_solid, size: 18),
                onPressed: () => _run(_stopPlayback),
              ),
            ),
          const SizedBox(width: 4),
          Tooltip(
            message: _sidebarVisible ? '收起播放侧栏' : '展开播放侧栏',
            child: IconButton(
              key: const ValueKey('playback-sidebar-toggle'),
              icon: Icon(
                FluentIcons.side_panel,
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

  Widget _buildStage(PlaybackStore store) => LayoutBuilder(
    builder: (context, constraints) {
      var size = playbackSurfaceSize(
        constraints.maxWidth,
        constraints.maxHeight,
        store.current != null && store.fit == PlaybackFit.fit
            ? store.aspectRatio
            : null,
      );
      var posterUrl = store.coverFor(_posterSubject);
      return Align(
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: ClipRRect(
            borderRadius: BTRadius.largeBR,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(
                  color: Colors.black,
                  child: store.current == null || store.video == null
                      ? _buildEmptyStage(posterUrl)
                      : material.Theme(
                          data: material.ThemeData.dark().copyWith(
                            colorScheme: material.ColorScheme.fromSeed(
                              seedColor: FluentTheme.of(context).accentColor,
                              brightness: material.Brightness.dark,
                            ),
                          ),
                          child: material.Material(
                            color: Colors.black,
                            child: Video(
                              key: _videoKey,
                              controller: store.video!,
                              fit: _playbackBoxFit(store.fit),
                              controls: (video) => _PlaybackVideoControls(
                                video: video,
                                store: store,
                                player: store.player!,
                                overlay: _overlay,
                                run: _run,
                                pickSubtitle: _pickSubtitle,
                              ),
                            ),
                          ),
                        ),
                ),
                if (store.error != null)
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 12,
                    child: InfoBar(
                      title: const Text('无法播放'),
                      content: Text(store.error!),
                      severity: InfoBarSeverity.error,
                      onClose: store.clearError,
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );

  Widget _buildEmptyStage(String? posterUrl) {
    var hasPoster = posterUrl != null && posterUrl.isNotEmpty;
    if (!hasPoster) {
      return Center(
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
    }
    // The poster keeps its natural size, centered on a black stage; the image
    // is only scaled down when it does not fit.
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: Colors.black),
        Center(
          child: BtBangumiCover(
            imageUrl: posterUrl,
            fit: BoxFit.contain,
            maxRequestEdge: BangumiCoverUrl.detailMaxEdge,
            errorBuilder: (context, {err}) => const SizedBox.shrink(),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '选择视频，开始观看',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => _run(_pickFile),
                  child: const Text('打开本地视频'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

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
                if (!_showHistory) ...[
                  const SizedBox(width: 4),
                  Tooltip(
                    message: '刷新播放列表',
                    child: IconButton(
                      key: const ValueKey('playback-refresh'),
                      icon: const Icon(FluentIcons.refresh, size: 15),
                      onPressed: store.canRefresh
                          ? () => _run(store.refresh)
                          : null,
                    ),
                  ),
                ],
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
    var item = store.playlist[index];
    var selected = store.index == index;
    var accent = FluentTheme.of(context).accentColor;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      child: Tooltip(
        message: item.title,
        child: HoverButton(
          key: ValueKey('playback-item-$index'),
          onPressed: store.loading || selected
              ? null
              : () => _run(() => store.jump(index)),
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
                if (item.subject != null) ...[
                  _playbackThumb(item, store, selected),
                  const SizedBox(width: 8),
                ],
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
                const SizedBox(width: 4),
                Tooltip(
                  message: '用外部播放器打开',
                  child: IconButton(
                    icon: const Icon(FluentIcons.open_file, size: 14),
                    onPressed: () => _run(() => _openExternalPlayer(item)),
                  ),
                ),
                Tooltip(
                  message: '打开所在目录',
                  child: IconButton(
                    icon: const Icon(FluentIcons.folder_open, size: 14),
                    onPressed: () => _run(() => _openVideoDirectory(item)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _playbackThumb(PlaybackItem item, PlaybackStore store, bool selected) {
    var coverUrl = store.coverFor(item.subject);
    var accent = FluentTheme.of(context).accentColor;
    Widget placeholder() => Container(
      color: BTColors.surfaceTertiary(context),
      child: Icon(
        FluentIcons.video,
        size: 14,
        color: selected ? accent : BTColors.textTertiary(context),
      ),
    );
    var child = coverUrl == null || coverUrl.isEmpty
        ? placeholder()
        : BtBangumiCover(
            imageUrl: coverUrl,
            fit: BoxFit.cover,
            width: 26,
            height: 38,
            maxRequestEdge: BangumiCoverUrl.thumbMaxEdge,
            errorBuilder: (context, {err}) => placeholder(),
          );
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(width: 26, height: 38, child: child),
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
                      onPressed: () => _openSubject(item.subject!),
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
