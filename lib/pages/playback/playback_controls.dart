part of 'playback_page.dart';

class _PlaybackVideoControls extends StatefulWidget {
  const _PlaybackVideoControls({
    required this.video,
    required this.store,
    required this.player,
    required this.overlay,
    required this.run,
    required this.pickFile,
    required this.stopPlayback,
    required this.pickSubtitle,
    required this.windowMode,
    required this.sidebarVisible,
    required this.buildLibraryPanel,
  });

  final VideoState video;
  final PlaybackStore store;
  final Player player;
  final _PlaybackOverlayController overlay;
  final Future<void> Function(Future<void> Function()) run;
  final Future<void> Function() pickFile;
  final Future<void> Function() stopPlayback;
  final Future<void> Function() pickSubtitle;
  final PlaybackWindowMode? windowMode;

  /// 内嵌播放页已显示侧栏时，底栏不再重复提供选集入口。
  final bool sidebarVisible;
  final Widget Function(_PlaybackLibrarySection section) buildLibraryPanel;

  @override
  State<_PlaybackVideoControls> createState() => _PlaybackVideoControlsState();
}

class _PlaybackVideoControlsState extends State<_PlaybackVideoControls> {
  final _contextMenu = FlyoutController();

  /// Shared width policy for playback menus. Wide enough that short menus look
  /// deliberate rather than cramped, narrow enough that no menu is padded out
  /// far past its content.
  static const _playbackMenuMinWidth = 220.0;
  static const _playbackMenuMaxWidth = 320.0;
  static const _playbackMenuMargin = 8.0;

  /// One node per controls instance. media_kit builds a second control set for
  /// the fullscreen route while the windowed one stays mounted; sharing a node
  /// makes the fullscreen attach detach the windowed one, which Flutter never
  /// re-attaches, so keyboard shortcuts die after leaving fullscreen.
  final _focus = FocusNode(debugLabel: 'playback-video-controls');
  StreamSubscription<double>? _volumeSubscription;
  Timer? _hideTimer;
  bool _chromeVisible = true;
  bool _barHovered = false;
  bool _seeking = false;
  bool _takingScreenshot = false;

  @override
  void initState() {
    super.initState();
    widget.overlay.menuClosers.add(_closeMenu);
    var volume = widget.player.state.volume;
    if (volume > 0) widget.overlay.audibleVolume = volume;
    _volumeSubscription = widget.player.stream.volume.listen((value) {
      if (value > 0) widget.overlay.audibleVolume = value;
    });
    _scheduleHide();
    _focusVideo();
  }

  void _showChrome() {
    if (!mounted) return;
    if (!_chromeVisible) {
      setState(() => _chromeVisible = true);
    }
    _scheduleHide();
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    if (_barHovered ||
        _seeking ||
        _contextMenu.isOpen ||
        widget.overlay.showHelp) {
      return;
    }
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted ||
          _seeking ||
          _contextMenu.isOpen ||
          widget.overlay.showHelp) {
        return;
      }
      setState(() => _chromeVisible = false);
    });
  }

  void _hoverBar(bool value) {
    _barHovered = value;
    _showChrome();
  }

  void _seekInteraction(bool value) {
    _seeking = value;
    _showChrome();
  }

  bool _closeMenu() {
    if (!_contextMenu.isOpen) return false;
    _contextMenu.forceClose();
    return true;
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    widget.overlay.menuClosers.remove(_closeMenu);
    unawaited(_volumeSubscription?.cancel());
    _contextMenu.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _focusVideo() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          !widget.overlay.showHelp &&
          TickerMode.valuesOf(context).enabled &&
          ModalRoute.of(context)?.isCurrent != false) {
        _focus.requestFocus();
      }
    });
  }

  Widget _buildUpscaleWarning(String warning) {
    var upscaler = widget.store.upscaler!;
    var restoreMode = upscaler.restorableMode;
    return GestureDetector(
      onDoubleTap: () {},
      child: InfoBar(
        title: const Text('视频超分'),
        content: Text(warning),
        severity: InfoBarSeverity.warning,
        isLong: true,
        onClose: upscaler.dismissWarning,
        action: restoreMode == null
            ? null
            : Tooltip(
                message: '重新应用「${restoreMode.label}」档位',
                child: Button(
                  onPressed: () =>
                      unawaited(widget.run(widget.store.restoreUpscaleMode)),
                  child: const Text('恢复超分配置'),
                ),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([widget.store, widget.windowMode]),
    builder: (context, _) {
      var item = widget.store.current;
      if (item == null || widget.store.player != widget.player) {
        return const SizedBox.shrink();
      }
      return ListenableBuilder(
        listenable: widget.overlay,
        builder: (context, _) => LayoutBuilder(
          builder: (context, constraints) {
            // 窗口缩放或启动过渡的极小尺寸放不下上下控制栏；先只显示画面，
            // 避免 RenderFlex 溢出。尺寸恢复后控制栏会自动回来。
            if (constraints.maxWidth < 300 || constraints.maxHeight < 140) {
              return const SizedBox.shrink();
            }
            var theme = _controlsTheme(constraints.maxWidth);
            var warningBottom = constraints.maxHeight >= 300 ? 92.0 : 16.0;
            return CallbackShortcuts(
              bindings: {
                for (var shortcut in _playbackShortcuts)
                  for (var activator in shortcut.activators)
                    activator: () => _execute(shortcut.command),
              },
              child: Focus(
                focusNode: _focus,
                autofocus: true,
                child: material.Theme(
                  data: material.ThemeData(
                    brightness: material.Brightness.dark,
                    fontFamily: 'SMonoSC',
                  ),
                  child: FlyoutTarget(
                    controller: _contextMenu,
                    child: Listener(
                      onPointerDown: (_) {
                        _focusVideo();
                      },
                      onPointerSignal: (event) {
                        if (event is PointerScrollEvent &&
                            !widget.overlay.showHelp &&
                            !_contextMenu.isOpen) {
                          GestureBinding.instance.pointerSignalResolver
                              .register(
                                event,
                                (_) => _execute(
                                  event.scrollDelta.dy > 0
                                      ? _PlaybackCommand.volumeDown
                                      : _PlaybackCommand.volumeUp,
                                ),
                              );
                        }
                      },
                      child: MouseRegion(
                        cursor: _chromeVisible || widget.overlay.showHelp
                            ? SystemMouseCursors.basic
                            : SystemMouseCursors.none,
                        onHover: (_) => _showChrome(),
                        onEnter: (_) => _showChrome(),
                        onExit: (_) {
                          _barHovered = false;
                          _scheduleHide();
                        },
                        child: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onSecondaryTapUp: _showContextMenu,
                          onDoubleTap: () =>
                              _execute(_PlaybackCommand.fullscreen),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              MaterialDesktopVideoControlsTheme(
                                normal: theme,
                                fullscreen: theme,
                                child: _buildChrome(theme),
                              ),
                              if (Platform.isWindows &&
                                  widget.store.tensorRtResources.visible &&
                                  !widget.overlay.showHelp &&
                                  constraints.maxHeight >= 220)
                                Positioned(
                                  right: 16,
                                  bottom: _chromeVisible ? 92 : 16,
                                  child: SizedBox(
                                    width: (constraints.maxWidth - 32).clamp(
                                      0.0,
                                      420.0,
                                    ),
                                    child: _PlaybackTensorRtProgress(
                                      key: ValueKey(widget.store.upscaleMode),
                                      store: widget.store,
                                      run: widget.run,
                                      maxHeight:
                                          constraints.maxHeight -
                                          (_chromeVisible ? 108 : 32),
                                    ),
                                  ),
                                ),
                              if (widget.overlay.showInfo)
                                Positioned.fill(
                                  left: 16,
                                  right: 16,
                                  top: constraints.maxHeight >= 300 ? 64 : 8,
                                  bottom: constraints.maxHeight >= 300 ? 92 : 8,
                                  child: RepaintBoundary(
                                    child: _PlaybackVideoInfo(
                                      key: ValueKey(item.key),
                                      player: widget.player,
                                      item: item,
                                      store: widget.store,
                                    ),
                                  ),
                                ),
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: _PlaybackFeedbackView(
                                    feedback: widget.overlay.feedback,
                                  ),
                                ),
                              ),
                              if (widget.overlay.showHelp)
                                Positioned.fill(
                                  child: _PlaybackShortcutHelp(
                                    onClose: () =>
                                        _execute(_PlaybackCommand.help),
                                  ),
                                ),
                              // Keep the notice in the video controls shared
                              // by windowed/fullscreen routes. Do not consume
                              // it before a visible surface can render it.
                              if (widget.store.upscaler?.warning
                                  case var warning?)
                                Positioned(
                                  left: 16,
                                  right: 16,
                                  bottom: warningBottom,
                                  child: Center(
                                    child: ConstrainedBox(
                                      constraints: BoxConstraints(
                                        maxWidth: 560,
                                        maxHeight:
                                            (constraints.maxHeight -
                                                    warningBottom -
                                                    16)
                                                .clamp(0.0, double.infinity),
                                      ),
                                      child: SingleChildScrollView(
                                        child: _buildUpscaleWarning(warning),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      );
    },
  );
}
