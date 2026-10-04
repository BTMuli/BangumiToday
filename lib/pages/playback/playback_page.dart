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
import '../../core/errors/playback_unavailable.dart';
import '../../core/theme/bt_theme.dart';
import '../../models/playback/playback_fit.dart';
import '../../models/playback/playback_history_group.dart';
import '../../models/playback/playback_item.dart';
import '../../models/playback/playback_rate.dart';
import '../../models/playback/playback_upscale.dart';
import '../../providers/episode_mark_providers.dart';
import '../../providers/playback_window_providers.dart';
import '../../store/nav_store.dart';
import '../../store/playback_store.dart';
import '../../ui/bt_infobar.dart';
import '../../widgets/bangumi/bt_bangumi_cover.dart';
import 'playback_actions.dart';
import 'playback_episode_mark.dart';
import 'playback_label.dart';
import 'playback_window_mode.dart';

part 'playback_controls.dart';
part 'playback_overlay.dart';
part 'playback_seek_bar.dart';
part 'playback_video_info.dart';
part 'playback_viewport.dart';
part 'playback_library_panel.dart';

class PlaybackPage extends ConsumerStatefulWidget {
  const PlaybackPage({super.key, this.independent = false, this.windowMode});
  final bool independent;
  final PlaybackWindowMode? windowMode;

  @override
  ConsumerState<PlaybackPage> createState() => _PlaybackPageState();
}

class _PlaybackPageState extends ConsumerState<PlaybackPage> {
  late final PlaybackStore _store;
  final _libraryKey = GlobalKey<_PlaybackLibraryPanelState>();
  final _stageKey = GlobalKey();
  final _videoKey = GlobalKey<VideoState>();
  final _overlay = _PlaybackOverlayController();
  bool _wasActive = true;
  bool _sidebarVisible = true;
  bool _noticeFramePending = false;
  String? _lastPlayingKey;
  int _lastPlayingIndex = -1;
  int? _posterSubject;

  @override
  void initState() {
    super.initState();
    _store = ref.read(playbackStoreProvider);
    widget.windowMode?.addListener(_onWindowModeChanged);
    _wasActive = _isPlaybackActive;
    _store.beforeVideoDispose = _exitVideoFullscreen;
    _onPlaybackChanged();
    unawaited(_run(_store.refreshHistory));
  }

  void _onWindowModeChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _toggleWindowFullscreen() async {
    var mode = widget.windowMode;
    if (mode == null || _store.current == null) return;
    await _exitVideoFullscreen();
    var box = _stageKey.currentContext?.findRenderObject() as RenderBox?;
    await mode.toggleVideoOnly(box?.size ?? const Size(960, 540));
  }

  /// 播放页是否为当前页
  bool get _isPlaybackActive {
    if (widget.independent) return true;
    var nav = ref.read(navStoreProvider);
    return nav.curIndex == nav.playbackIndex;
  }

  void _onNavigation() {
    var active = _isPlaybackActive;
    if (_wasActive && !active) unawaited(_run(_store.pause));
    _wasActive = active;
    if (active) _schedulePlaybackNotices();
  }

  void _schedulePlaybackNotices() {
    if (_noticeFramePending ||
        (_store.error == null && _store.upscaler?.warning == null)) {
      return;
    }
    _noticeFramePending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _noticeFramePending = false;
      if (!mounted || !_isPlaybackActive) return;
      var error = _store.error;
      if (error != null) {
        _store.clearError();
        unawaited(BtInfobar.error(context, error));
      }
      var upscaler = _store.upscaler;
      var warning = upscaler?.warning;
      if (warning != null) {
        upscaler!.dismissWarning();
        unawaited(BtInfobar.warn(context, '视频超分：$warning'));
      }
    });
  }

  void _onPlaybackChanged() {
    var key = _store.current?.key;
    if (key == _lastPlayingKey && _store.index == _lastPlayingIndex) return;
    _lastPlayingKey = key;
    _lastPlayingIndex = _store.index;
    if (key == null &&
        !_store.isClosed &&
        (widget.windowMode?.videoOnly ?? false)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _store.isClosed || _store.current != null) return;
        unawaited(
          _run(() async {
            await _exitVideoFullscreen();
            await widget.windowMode?.exitVideoOnly();
          }),
        );
      });
    }
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
    _libraryKey.currentState?.revealCurrent();
  }

  @override
  void dispose() {
    if (_store.beforeVideoDispose == _exitVideoFullscreen) {
      _store.beforeVideoDispose = null;
    }
    widget.windowMode?.removeListener(_onWindowModeChanged);
    _overlay.dispose();
    if (!widget.independent) {
      unawaited(_store.pause().catchError((Object _) {}));
    }
    super.dispose();
  }

  Future<void> _exitVideoFullscreen() async {
    if (_overlay.closeMenus()) await WidgetsBinding.instance.endOfFrame;
    var video = _videoKey.currentState;
    if (video != null && video.isFullscreen()) await video.exitFullscreen();
  }

  Future<void> _stopPlayback() async {
    await _exitVideoFullscreen();
    if (widget.windowMode?.videoOnly ?? false) {
      await widget.windowMode!.exitVideoOnly();
    }
    await _store.stop();
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      if (mounted) await reportPlaybackError(context, ref, error);
    }
  }

  Future<void> _pickFile() async {
    var file = await pickPlaybackFile();
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
    await _exitVideoFullscreen();
    await ref.read(playbackSubjectNavigationProvider)(subject);
  }

  @override
  Widget build(BuildContext context) {
    var store = ref.watch(playbackStoreProvider);
    // 离开播放页时暂停播放，替代原先对导航 store 的 addListener。
    if (!widget.independent) {
      ref.listen<int>(
        navStoreProvider.select((state) => state.curIndex),
        (_, _) => _onNavigation(),
      );
    }
    _onPlaybackChanged();
    _schedulePlaybackNotices();
    if (widget.windowMode?.videoOnly ?? false) {
      return PlaybackWindowResizeFrame(child: _buildStage(store));
    }
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
                  var sidebar = _buildLibraryPanel(key: _libraryKey);
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
          if (current != null && widget.windowMode != null)
            Tooltip(
              message: '窗口全屏（W）',
              child: IconButton(
                icon: const Icon(material.Icons.fit_screen_rounded, size: 19),
                onPressed: widget.windowMode!.transitioning
                    ? null
                    : () => _run(_toggleWindowFullscreen),
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
                if (_sidebarVisible) _revealCurrent();
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
        widget.windowMode?.videoOnly != true &&
                store.current != null &&
                store.fit == PlaybackFit.fit
            ? store.aspectRatio
            : null,
      );
      var posterUrl = store.coverFor(_posterSubject);
      return Align(
        child: SizedBox(
          key: _stageKey,
          width: size.width,
          height: size.height,
          child: ClipRRect(
            borderRadius: widget.windowMode?.videoOnly == true
                ? BorderRadius.zero
                : BTRadius.largeBR,
            child: ColoredBox(
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
                          onEnterFullscreen:
                              widget.windowMode?.enterScreenFullscreen ??
                              defaultEnterNativeFullscreen,
                          onExitFullscreen:
                              widget.windowMode?.exitScreenFullscreen ??
                              defaultExitNativeFullscreen,
                          controls: (video) => _PlaybackViewportReporter(
                            store: store,
                            child: _PlaybackVideoControls(
                              video: video,
                              store: store,
                              player: store.player!,
                              overlay: _overlay,
                              run: _run,
                              pickSubtitle: _pickSubtitle,
                              windowMode: widget.windowMode,
                              toggleWindowFullscreen: _toggleWindowFullscreen,
                              buildLibraryPanel: _buildLibraryPanel,
                            ),
                          ),
                        ),
                      ),
                    ),
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

  Widget _buildLibraryPanel({Key? key}) => _PlaybackLibraryPanel(
    key: key,
    run: _run,
    openExternalPlayer: _openExternalPlayer,
    openVideoDirectory: _openVideoDirectory,
    openSubject: _openSubject,
  );

  static String _time(int milliseconds) {
    var seconds = milliseconds ~/ 1000;
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }
}
