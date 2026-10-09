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
import '../../core/utils/tool_func.dart';
import '../../models/playback/playback_chapter.dart';
import '../../models/playback/playback_episode_layout.dart';
import '../../models/playback/playback_geometry.dart';
import '../../models/playback/playback_history_group.dart';
import '../../models/playback/playback_item.dart';
import '../../models/playback/playback_on_top.dart';
import '../../models/playback/playback_rate.dart';
import '../../models/playback/playback_subtitle.dart';
import '../../models/playback/playback_upscale.dart';
import '../../providers/episode_mark_providers.dart';
import '../../providers/playback_window_providers.dart';
import '../../store/nav_store.dart';
import '../../store/playback_store.dart';
import '../../tools/log_tool.dart';
import '../../ui/bt_infobar.dart';
import '../../widgets/bangumi/bt_bangumi_cover.dart';
import '../../widgets/playback/playback_build_log.dart';
import 'playback_actions.dart';
import 'playback_episode_mark.dart';
import 'playback_label.dart';
import 'playback_window_mode.dart';

part 'playback_controls.dart';
part 'playback_overlay.dart';
part 'playback_seek_bar.dart';
part 'playback_video_info.dart';
part 'playback_tensorrt_progress.dart';
part 'playback_viewport.dart';
part 'playback_library_panel.dart';
part 'playback_loading.dart';

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
  final _libraryFlyout = FlyoutController();
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

  /// 未载入视频时也能查看播放记录：无边框窗口没有侧栏，浮出同一个记录面板。
  void _showLibraryFlyout(BuildContext buttonContext) {
    var navigatorBox =
        Navigator.of(context).context.findRenderObject() as RenderBox;
    var layout = _playbackLibraryFlyoutLayout(
      buttonContext: buttonContext,
      navigatorBox: navigatorBox,
      besideButton: true,
    );
    unawaited(
      _run(() async {
        await _libraryFlyout.showFlyout<void>(
          placementMode: FlyoutPlacementMode.bottomLeft,
          position: layout.position,
          builder: (_) => _playbackLibraryFlyout(
            _buildLibraryPanel(section: _PlaybackLibrarySection.history),
            layout.size,
          ),
        );
      }),
    );
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
        unawaited(
          displayInfoBar(
            context,
            alignment: Alignment.bottomCenter,
            duration: const Duration(seconds: 12),
            builder: (_, close) => InfoBar(
              title: const Text('视频超分'),
              content: Text(warning),
              severity: InfoBarSeverity.warning,
              action: IconButton(
                icon: const Icon(FluentIcons.chrome_close),
                onPressed: close,
              ),
            ),
          ),
        );
      }
    });
  }

  void _onPlaybackChanged() {
    var key = _store.current?.key;
    if (key == _lastPlayingKey && _store.index == _lastPlayingIndex) return;
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
    _libraryKey.currentState?.revealCurrent();
  }

  @override
  void dispose() {
    if (_store.beforeVideoDispose == _exitVideoFullscreen) {
      _store.beforeVideoDispose = null;
    }
    widget.windowMode?.removeListener(_onWindowModeChanged);
    _overlay.dispose();
    _libraryFlyout.dispose();
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

  Future<void> _enterWindowFullscreen() async {
    try {
      await widget.windowMode!.enterScreenFullscreen();
    } catch (_) {
      // media_kit pushes the video route before invoking the native callback.
      // Undo that route too when the native transition rolls back.
      await WidgetsBinding.instance.endOfFrame;
      // The enter callback still holds media_kit's fullscreen lock. Queue the
      // pop without awaiting it so that throwing releases that lock first.
      if (mounted) unawaited(_run(_exitVideoFullscreen));
      rethrow;
    }
  }

  Future<void> _changeVideoFullscreen(Future<void> Function() action) async {
    _store.beginViewportTransition();
    try {
      await action();
    } finally {
      try {
        // Viewport reporters publish post-frame, after the native bounds and
        // fullscreen route have settled. Apply only that final physical size.
        await WidgetsBinding.instance.endOfFrame;
      } finally {
        _store.endViewportTransition();
      }
    }
  }

  Future<void> _enterVideoFullscreen() => _changeVideoFullscreen(
    widget.windowMode == null
        ? defaultEnterNativeFullscreen
        : _enterWindowFullscreen,
  );

  Future<void> _leaveVideoFullscreen() => _changeVideoFullscreen(
    widget.windowMode == null
        ? defaultExitNativeFullscreen
        : _exitWindowFullscreen,
  );

  Future<void> _exitWindowFullscreen() async {
    try {
      await widget.windowMode!.exitScreenFullscreen();
    } catch (error) {
      // The route pop does not await media_kit's exit callback. Restore the
      // route after native rollback and report the failure here.
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      var video = _videoKey.currentState;
      if (widget.windowMode!.screenFullscreen &&
          video != null &&
          !video.isFullscreen()) {
        try {
          await video.enterFullscreen();
        } catch (restoreError) {
          BTLogTool.warn('恢复播放器全屏页面失败：$restoreError');
        }
      }
      if (mounted) await reportPlaybackError(context, ref, error);
    }
  }

  Future<void> _stopPlayback() async {
    await _exitVideoFullscreen();
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
      await _store.setSubtitleTrack(SubtitleTrack.uri(file.path));
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
    // 独立播放器在主窗口打开章节页，保留播放窗口的全屏状态。
    if (widget.independent) {
      _overlay.closeMenus();
    } else {
      await _exitVideoFullscreen();
    }
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
    // 独立播放器窗口只有视频画面；主窗口保留内嵌播放页与侧栏。
    if (widget.windowMode != null) {
      var mode = widget.windowMode!;
      return FlyoutTarget(
        controller: _libraryFlyout,
        child: PlaybackWindowResizeFrame(
          onResizeStart: (edge) =>
              unawaited(_run(() => mode.beginResize(edge))),
          child: _buildStage(store),
        ),
      );
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
    var label = current == null
        ? null
        : PlaybackLabel.fromName(current.title, filePath: current.filePath);
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
              icon: const Icon(material.Icons.video_file_outlined, size: 19),
              onPressed: store.isOpening ? null : () => _run(_pickFile),
            ),
          ),
          if (current != null)
            Tooltip(
              message: '停止播放',
              child: IconButton(
                icon: const Icon(material.Icons.stop_circle_outlined, size: 19),
                onPressed: () => _run(_stopPlayback),
              ),
            ),
          const SizedBox(width: 4),
          Tooltip(
            message: _sidebarVisible ? '收起播放侧栏' : '展开播放侧栏',
            child: IconButton(
              key: const ValueKey('playback-sidebar-toggle'),
              icon: Transform.flip(
                flipX: true,
                child: Icon(
                  material.Icons.view_sidebar_outlined,
                  size: 19,
                  color: _sidebarVisible
                      ? FluentTheme.of(context).accentColor
                      : BTColors.textSecondary(context),
                ),
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
      // 独立播放器窗口本身保持视频比例，视口直接铺满；内嵌播放页让画布跟随
      // 视频比例，避免黑边占用侧栏空间。
      var size = playbackSurfaceSize(
        constraints.maxWidth,
        constraints.maxHeight,
        widget.windowMode == null && store.current != null
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
            borderRadius: widget.windowMode == null
                ? BTRadius.largeBR
                : BorderRadius.zero,
            child: ColoredBox(
              color: Colors.black,
              child: store.current == null || store.video == null
                  ? _buildEmptyStage(posterUrl)
                  : material.Theme(
                      data:
                          material.ThemeData(
                            brightness: material.Brightness.dark,
                            fontFamily: 'SMonoSC',
                          ).copyWith(
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
                          fit: BoxFit.contain,
                          onEnterFullscreen: _enterVideoFullscreen,
                          onExitFullscreen: _leaveVideoFullscreen,
                          controls: (video) => _PlaybackViewportReporter(
                            store: store,
                            child: RepaintBoundary(
                              child: _PlaybackVideoControls(
                                video: video,
                                store: store,
                                player: store.player!,
                                overlay: _overlay,
                                run: _run,
                                pickFile: _pickFile,
                                stopPlayback: _stopPlayback,
                                pickSubtitle: _pickSubtitle,
                                windowMode: widget.windowMode,
                                // 只有内嵌播放页会显示侧栏；独立窗口始终用浮出层。
                                sidebarVisible:
                                    widget.windowMode == null &&
                                    _sidebarVisible,
                                buildLibraryPanel: (section) =>
                                    _buildLibraryPanel(section: section),
                              ),
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
    var mode = widget.windowMode;
    var hasPoster = posterUrl != null && posterUrl.isNotEmpty;
    var status = _store.openingStatus;
    var content = status != null
        ? _PlaybackLoadingIndicator(
            message: status,
            filePath: _store.openingFile,
          )
        : hasPoster
        ? _buildPosterStage(posterUrl)
        : _buildBlankStage();
    if (mode == null) return content;
    // 无边框窗口没有标题栏：空态仍要能拖动、置顶、最小化和关闭。
    return Stack(
      fit: StackFit.expand,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (_) => unawaited(_run(mode.beginDrag)),
          onPanUpdate: (_) => unawaited(mode.updateDrag()),
          onPanEnd: (_) => unawaited(_run(mode.endDrag)),
          onPanCancel: () => unawaited(_run(mode.endDrag)),
          child: content,
        ),
        Positioned(
          top: 8,
          right: 8,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Tooltip(
                message: _playbackOnTopTooltip(mode.onTop),
                child: material.IconButton(
                  color: Colors.white,
                  icon: _PlaybackOnTopIcon(
                    onTop: mode.onTop,
                    size: 20,
                    color: Colors.white,
                  ),
                  onPressed: () => _run(() => mode.setOnTop(mode.onTop.next)),
                ),
              ),
              Tooltip(
                message: '最小化',
                child: material.IconButton(
                  color: Colors.white,
                  icon: const Icon(material.Icons.remove_rounded, size: 20),
                  onPressed: () => unawaited(_run(mode.minimize)),
                ),
              ),
              Tooltip(
                message: '关闭播放器',
                child: material.IconButton(
                  color: Colors.white,
                  icon: const Icon(material.Icons.close_rounded, size: 20),
                  onPressed: () => unawaited(_run(mode.closeWindow)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBlankStage() => Center(
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
          _buildEmptyStageActions(),
        ],
      ),
    ),
  );

  /// 空态操作：打开本地视频；独立窗口另外提供播放记录入口。
  Widget _buildEmptyStageActions() => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      FilledButton(
        onPressed: () => _run(_pickFile),
        child: const Text('打开本地视频'),
      ),
      if (widget.windowMode != null) ...[
        const SizedBox(width: 8),
        Builder(
          builder: (buttonContext) => Button(
            onPressed: () => _showLibraryFlyout(buttonContext),
            child: const Text('播放记录'),
          ),
        ),
      ],
    ],
  );

  /// The poster keeps its natural size, centered on a black stage; the image
  /// is only scaled down when it does not fit.
  Widget _buildPosterStage(String posterUrl) => Stack(
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
      Positioned(
        left: 0,
        right: 0,
        bottom: 0,
        child: Container(
          // 底部文案压在封面图上，用整宽渐变压暗保证可读。
          padding: const EdgeInsets.fromLTRB(24, 56, 24, 28),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x00000000), Color(0xCC000000)],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '选择视频，开始观看',
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
              const SizedBox(height: 12),
              _buildEmptyStageActions(),
            ],
          ),
        ),
      ),
    ],
  );

  Widget _buildLibraryPanel({Key? key, _PlaybackLibrarySection? section}) =>
      _PlaybackLibraryPanel(
        key: key,
        section: section,
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
