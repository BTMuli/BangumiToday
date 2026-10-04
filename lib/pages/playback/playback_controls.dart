part of 'playback_page.dart';

class _PlaybackVideoControls extends StatefulWidget {
  const _PlaybackVideoControls({
    required this.video,
    required this.store,
    required this.player,
    required this.overlay,
    required this.run,
    required this.pickSubtitle,
  });

  final VideoState video;
  final PlaybackStore store;
  final Player player;
  final _PlaybackOverlayController overlay;
  final Future<void> Function(Future<void> Function()) run;
  final Future<void> Function() pickSubtitle;

  @override
  State<_PlaybackVideoControls> createState() => _PlaybackVideoControlsState();
}

class _PlaybackVideoControlsState extends State<_PlaybackVideoControls> {
  final _contextMenu = FlyoutController();

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

  void _execute(_PlaybackCommand command) {
    unawaited(widget.run(() => _perform(command)));
  }

  Future<void> _perform(_PlaybackCommand command) async {
    var store = widget.store;
    var player = widget.player;
    var overlay = widget.overlay;
    if (!mounted || store.player != player || store.current == null) return;
    _showChrome();
    if (command == _PlaybackCommand.info) {
      overlay.toggleInfo();
      return;
    }
    if (command == _PlaybackCommand.help) {
      overlay.toggleHelp();
      _scheduleHide();
      if (!overlay.showHelp) _focusVideo();
      return;
    }
    if (command == _PlaybackCommand.escape) {
      if (overlay.showHelp) {
        overlay.toggleHelp();
        _focusVideo();
        _scheduleHide();
      } else if (isFullscreen(context)) {
        overlay.closeMenus();
        await exitFullscreen(context);
        overlay.show('退出全屏', material.Icons.fullscreen_exit_rounded);
      }
      return;
    }
    if (command == _PlaybackCommand.fullscreen) {
      var fullscreen = isFullscreen(context);
      overlay.closeMenus();
      await toggleFullscreen(context);
      overlay.show(
        fullscreen ? '退出全屏' : '进入全屏',
        fullscreen
            ? material.Icons.fullscreen_exit_rounded
            : material.Icons.fullscreen_rounded,
      );
      return;
    }
    if (store.loading) {
      overlay.show('正在加载视频…', material.Icons.hourglass_top_rounded);
      return;
    }
    switch (command) {
      case _PlaybackCommand.toggle:
      case _PlaybackCommand.play:
      case _PlaybackCommand.pause:
        var pause =
            command == _PlaybackCommand.pause ||
            (command == _PlaybackCommand.toggle && player.state.playing);
        await (pause ? store.pause() : player.play());
        overlay.show(
          pause ? '已暂停' : '继续播放',
          pause
              ? material.Icons.pause_rounded
              : material.Icons.play_arrow_rounded,
        );
      case _PlaybackCommand.back5:
      case _PlaybackCommand.forward5:
      case _PlaybackCommand.back10:
      case _PlaybackCommand.forward10:
        var seconds = switch (command) {
          _PlaybackCommand.back5 => -5,
          _PlaybackCommand.forward5 => 5,
          _PlaybackCommand.back10 => -10,
          _ => 10,
        };
        var duration = player.state.duration;
        var target = player.state.position + Duration(seconds: seconds);
        if (target < Duration.zero) target = Duration.zero;
        if (duration > Duration.zero && target > duration) target = duration;
        await player.seek(target);
        overlay.show(
          '${seconds < 0 ? '后退' : '前进'} ${seconds.abs()} 秒',
          seconds < 0
              ? material.Icons.fast_rewind_rounded
              : material.Icons.fast_forward_rounded,
          detail: '${_playbackTime(target)} / ${_playbackTime(duration)}',
          level: duration > Duration.zero
              ? target.inMilliseconds / duration.inMilliseconds
              : null,
        );
      case _PlaybackCommand.volumeUp:
      case _PlaybackCommand.volumeDown:
      case _PlaybackCommand.mute:
        var volume = player.state.volume;
        if (command == _PlaybackCommand.mute) {
          if (volume > 0) {
            overlay.audibleVolume = volume;
            volume = 0;
          } else {
            volume = overlay.audibleVolume;
          }
        } else {
          volume = (volume + (command == _PlaybackCommand.volumeUp ? 5 : -5))
              .clamp(0.0, 100.0);
        }
        await player.setVolume(volume);
        if (volume > 0) overlay.audibleVolume = volume;
        overlay.show(
          volume == 0 ? '已静音' : '音量 ${volume.round()}%',
          volume == 0
              ? material.Icons.volume_off_rounded
              : material.Icons.volume_up_rounded,
          level: volume / 100,
        );
      case _PlaybackCommand.slower:
      case _PlaybackCommand.faster:
        await store.stepRate(command == _PlaybackCommand.faster ? 0.1 : -0.1);
        overlay.show(
          '播放速度 ${PlaybackRateMemory.label(player.state.rate)}×',
          material.Icons.speed_rounded,
        );
      case _PlaybackCommand.toggleRate:
        await store.toggleRate();
        overlay.show(
          '播放速度 ${PlaybackRateMemory.label(player.state.rate)}×',
          material.Icons.speed_rounded,
          detail: store.rememberedRate == null
              ? '先调整倍速，再按 Z 记录并切回 1×'
              : 'Z 可切换 1× / ${PlaybackRateMemory.label(store.rememberedRate!)}×',
        );
      case _PlaybackCommand.previous:
      case _PlaybackCommand.next:
        var nextIndex =
            store.index + (command == _PlaybackCommand.next ? 1 : -1);
        if (nextIndex < 0 || nextIndex >= store.playlist.length) {
          overlay.show(
            nextIndex < 0 ? '已经是第一个视频' : '已经是最后一个视频',
            material.Icons.playlist_play_rounded,
          );
          return;
        }
        await store.jump(nextIndex);
        if (store.player != player || store.current == null) return;
        overlay.show(
          command == _PlaybackCommand.next ? '下一个视频' : '上一个视频',
          command == _PlaybackCommand.next
              ? material.Icons.skip_next_rounded
              : material.Icons.skip_previous_rounded,
          detail: PlaybackLabel.fromName(store.current!.title).title,
        );
      case _PlaybackCommand.fullscreen:
      case _PlaybackCommand.escape:
      case _PlaybackCommand.info:
      case _PlaybackCommand.help:
        return;
      case _PlaybackCommand.screenshot:
        await _copyScreenshot();
    }
  }

  Future<void> _copyScreenshot() async {
    if (_takingScreenshot) return;
    _takingScreenshot = true;
    var player = widget.player;
    var itemKey = widget.store.current!.key;
    var position = player.state.position;
    try {
      var image = await player.screenshot(
        format: 'image/png',
        includeLibassSubtitles: true,
      );
      if (!mounted ||
          widget.store.player != player ||
          widget.store.current?.key != itemKey) {
        return;
      }
      if (image == null || image.isEmpty) {
        throw const PlaybackUnavailable('当前没有可截取的视频画面');
      }
      var systemClipboard = clipboard.SystemClipboard.instance;
      if (systemClipboard == null) {
        throw const PlaybackUnavailable('当前平台不支持复制图片到剪贴板');
      }
      var item = clipboard.DataWriterItem()..add(clipboard.Formats.png(image));
      await systemClipboard.write([item]);
      widget.overlay.show(
        '截图已复制到剪贴板',
        material.Icons.photo_camera_outlined,
        detail: _playbackTime(position),
      );
    } finally {
      _takingScreenshot = false;
    }
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

  MaterialDesktopVideoControlsThemeData _controlsTheme(double width) {
    var store = widget.store;
    var player = widget.player;
    var item = store.current!;
    var label = PlaybackLabel.fromName(item.title);
    var accent = FluentTheme.of(context).accentColor;
    return MaterialDesktopVideoControlsThemeData(
      buttonBarHeight: 48,
      buttonBarButtonSize: 20,
      volumeBarActiveColor: accent,
      volumeBarThumbColor: accent,
      topButtonBar: [
        Expanded(
          child: Tooltip(
            message: item.title,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  [
                    if (label.episode != null) label.episode!,
                    if (label.details.isNotEmpty) label.details,
                    '${store.index + 1} / ${store.playlist.length}',
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: material.Colors.white70,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        _videoButton(
          material.Icons.info_outline_rounded,
          '视频信息（Tab）',
          () => _execute(_PlaybackCommand.info),
          key: const ValueKey('playback-video-info'),
          selected: widget.overlay.showInfo,
        ),
        _videoButton(
          material.Icons.keyboard_alt_outlined,
          '查看快捷键（F1）',
          () => _execute(_PlaybackCommand.help),
          key: const ValueKey('playback-shortcuts'),
          selected: widget.overlay.showHelp,
        ),
      ],
      bottomButtonBar: [
        const MaterialDesktopPositionIndicator(
          style: TextStyle(color: Colors.white, fontSize: 12),
        ),
        const SizedBox(width: 12),
        if (width > 820)
          _videoButton(
            material.Icons.skip_previous_rounded,
            '上一个视频',
            store.index > 0 && !store.loading
                ? () => _execute(_PlaybackCommand.previous)
                : null,
          ),
        StreamBuilder<bool>(
          stream: player.stream.playing,
          initialData: player.state.playing,
          builder: (_, playing) => _videoButton(
            playing.data == true
                ? material.Icons.pause_rounded
                : material.Icons.play_arrow_rounded,
            playing.data == true ? '暂停' : '继续播放',
            () => _execute(_PlaybackCommand.toggle),
            key: const ValueKey('playback-toggle'),
          ),
        ),
        if (width > 820)
          _videoButton(
            material.Icons.skip_next_rounded,
            '下一个视频',
            store.index + 1 < store.playlist.length && !store.loading
                ? () => _execute(_PlaybackCommand.next)
                : null,
          ),
        if (width > 700) ...[
          _videoButton(
            material.Icons.replay_10_rounded,
            '后退 10 秒',
            () => _execute(_PlaybackCommand.back10),
          ),
          _videoButton(
            material.Icons.forward_10_rounded,
            '前进 10 秒',
            () => _execute(_PlaybackCommand.forward10),
          ),
        ],
        if (width > 520) const MaterialDesktopVolumeButton(),
        const Spacer(),
        _PlaybackSettingsButton(player: player, onPressed: _showSettings),
        _videoButton(
          isFullscreen(context)
              ? material.Icons.fullscreen_exit_rounded
              : material.Icons.fullscreen_rounded,
          '切换全屏（F / Enter）',
          () => _execute(_PlaybackCommand.fullscreen),
        ),
      ],
    );
  }

  Widget _videoButton(
    IconData icon,
    String tooltip,
    VoidCallback? onPressed, {
    Key? key,
    bool selected = false,
  }) => Tooltip(
    message: tooltip,
    child: material.IconButton(
      key: key,
      padding: const EdgeInsets.all(6),
      constraints: const BoxConstraints(minWidth: 34, minHeight: 36),
      iconSize: 22,
      color: selected ? FluentTheme.of(context).accentColor : Colors.white,
      disabledColor: Colors.white.withValues(alpha: 0.25),
      onPressed: onPressed,
      icon: Icon(icon),
    ),
  );

  void _showSettings(BuildContext buttonContext) {
    var navigatorBox =
        Navigator.of(context).context.findRenderObject() as RenderBox;
    var buttonBox = buttonContext.findRenderObject() as RenderBox;
    _showMenu(
      buttonBox.localToGlobal(Offset.zero, ancestor: navigatorBox),
      () => _playbackSettingsItems(
        widget.player,
        widget.store,
        widget.run,
        widget.pickSubtitle,
        _setFit,
        _execute,
      ),
    );
  }

  void _showMenu(Offset position, List<MenuFlyoutItemBase> Function() items) {
    _showChrome();
    _hideTimer?.cancel();
    unawaited(
      widget.run(() async {
        try {
          await _contextMenu.showFlyout<void>(
            position: position,
            builder: (_) => MenuFlyout(items: items()),
          );
        } finally {
          if (mounted) {
            _barHovered = false;
            _showChrome();
            _focusVideo();
          }
        }
      }),
    );
  }

  Future<void> _setFit(PlaybackFit mode) async {
    await widget.store.setFit(mode);
    if (!mounted) return;
    // Fullscreen shares these parameters with the windowed Video surface.
    widget.video.update(fit: _playbackBoxFit(widget.store.fit));
    widget.overlay.show(
      mode.label,
      material.Icons.aspect_ratio_rounded,
      detail: mode.description,
    );
  }

  void _showContextMenu(TapUpDetails details) {
    var navigator = Navigator.of(context);
    var box = navigator.context.findRenderObject() as RenderBox;
    var player = widget.player;
    var overlay = widget.overlay;
    var canPrevious = widget.store.index > 0;
    var canNext = widget.store.index + 1 < widget.store.playlist.length;
    _showMenu(
      box.globalToLocal(details.globalPosition),
      () => [
        MenuFlyoutItem(
          text: Text(player.state.playing ? '暂停' : '继续播放'),
          trailing: const _PlaybackMenuShortcut('Space / K'),
          onPressed: () => _execute(_PlaybackCommand.toggle),
        ),
        MenuFlyoutSubItem(
          text: const Text('播放与跳转'),
          items: (_) => [
            MenuFlyoutItem(
              text: const Text('后退 10 秒'),
              trailing: const _PlaybackMenuShortcut('J'),
              onPressed: () => _execute(_PlaybackCommand.back10),
            ),
            MenuFlyoutItem(
              text: const Text('前进 10 秒'),
              trailing: const _PlaybackMenuShortcut('L'),
              onPressed: () => _execute(_PlaybackCommand.forward10),
            ),
            const MenuFlyoutSeparator(),
            MenuFlyoutItem(
              text: const Text('上一个视频'),
              trailing: _PlaybackMenuShortcut('Page Up', enabled: canPrevious),
              onPressed: canPrevious
                  ? () => _execute(_PlaybackCommand.previous)
                  : null,
            ),
            MenuFlyoutItem(
              text: const Text('下一个视频'),
              trailing: _PlaybackMenuShortcut('Page Down', enabled: canNext),
              onPressed: canNext ? () => _execute(_PlaybackCommand.next) : null,
            ),
          ],
        ),
        ToggleMenuFlyoutItem(
          text: const Text('静音'),
          trailing: const _PlaybackMenuShortcut('M'),
          value: player.state.volume == 0,
          onChanged: (_) => _execute(_PlaybackCommand.mute),
        ),
        const MenuFlyoutSeparator(),
        ..._playbackSettingsItems(
          player,
          widget.store,
          widget.run,
          widget.pickSubtitle,
          _setFit,
          _execute,
        ),
        const MenuFlyoutSeparator(),
        MenuFlyoutItem(
          text: const Text('截屏并复制到剪贴板'),
          trailing: const _PlaybackMenuShortcut('S'),
          onPressed: () => _execute(_PlaybackCommand.screenshot),
        ),
        const MenuFlyoutSeparator(),
        MenuFlyoutItem(
          text: Text(isFullscreen(context) ? '退出全屏' : '进入全屏'),
          trailing: const _PlaybackMenuShortcut('F / Enter'),
          onPressed: () => _execute(_PlaybackCommand.fullscreen),
        ),
        ToggleMenuFlyoutItem(
          text: const Text('视频信息覆盖层'),
          trailing: const _PlaybackMenuShortcut('Tab'),
          value: overlay.showInfo,
          onChanged: (_) => _execute(_PlaybackCommand.info),
        ),
        MenuFlyoutItem(
          text: const Text('查看快捷键'),
          trailing: const _PlaybackMenuShortcut('F1'),
          onPressed: () => _execute(_PlaybackCommand.help),
        ),
      ],
    );
  }

  Widget _buildChrome(MaterialDesktopVideoControlsThemeData theme) => Stack(
    fit: StackFit.expand,
    children: [
      IgnorePointer(
        ignoring: !_chromeVisible,
        child: AnimatedOpacity(
          opacity: _chromeVisible ? 1 : 0,
          duration: const Duration(milliseconds: 150),
          child: Stack(
            fit: StackFit.expand,
            children: [
              for (var top in [true, false])
                Positioned(
                  left: 0,
                  right: 0,
                  top: top ? 0 : null,
                  bottom: top ? null : 0,
                  height: top ? 90 : 100,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: top
                              ? Alignment.topCenter
                              : Alignment.bottomCenter,
                          end: top
                              ? Alignment.bottomCenter
                              : Alignment.topCenter,
                          colors: const [Color(0x99000000), Color(0x00000000)],
                        ),
                      ),
                    ),
                  ),
                ),
              SafeArea(
                child: Column(
                  children: [
                    MouseRegion(
                      onEnter: (_) => _hoverBar(true),
                      onExit: (_) => _hoverBar(false),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: SizedBox(
                          height: 48,
                          child: Row(children: theme.topButtonBar),
                        ),
                      ),
                    ),
                    const Spacer(),
                    MouseRegion(
                      onEnter: (_) => _hoverBar(true),
                      onExit: (_) => _hoverBar(false),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _PlaybackSeekBar(
                            key: ValueKey(widget.store.current!.key),
                            player: widget.player,
                            run: widget.run,
                            onInteraction: _seekInteraction,
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: SizedBox(
                              height: 48,
                              child: Row(children: theme.bottomButtonBar),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      IgnorePointer(
        child: StreamBuilder<bool>(
          stream: widget.player.stream.buffering,
          initialData: widget.player.state.buffering,
          builder: (_, snapshot) => snapshot.data == true
              ? const Center(
                  child: SizedBox.square(
                    dimension: 32,
                    child: material.CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.store,
    builder: (context, _) {
      var item = widget.store.current;
      if (item == null || widget.store.player != widget.player) {
        return const SizedBox.shrink();
      }
      return ListenableBuilder(
        listenable: widget.overlay,
        builder: (context, _) => LayoutBuilder(
          builder: (context, constraints) {
            var theme = _controlsTheme(constraints.maxWidth);
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
                  data: material.ThemeData.dark(),
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
                              if ((ModalRoute.of(context)?.isCurrent ?? true) &&
                                  !widget.overlay.showInfo &&
                                  !widget.overlay.showHelp)
                                Positioned(
                                  left: 12,
                                  right: 12,
                                  top: 64,
                                  child: PlaybackEpisodeMarkPrompt(
                                    beforeOpenSubject: () async {
                                      if (widget.video.isFullscreen()) {
                                        await widget.video.exitFullscreen();
                                      }
                                    },
                                  ),
                                ),
                              if (widget.overlay.showInfo)
                                Positioned.fill(
                                  left: 16,
                                  right: 16,
                                  top: constraints.maxHeight >= 300 ? 64 : 8,
                                  bottom: constraints.maxHeight >= 300 ? 92 : 8,
                                  child: _PlaybackVideoInfo(
                                    key: ValueKey(item.key),
                                    player: widget.player,
                                    item: item,
                                    store: widget.store,
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

/// Shortcut hints follow the flyout's text colors, including disabled items.
class _PlaybackMenuShortcut extends StatelessWidget {
  const _PlaybackMenuShortcut(this.label, {this.enabled = true});

  final String label;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    var colors = FluentTheme.of(context).resources;
    return Text(
      label,
      style: TextStyle(
        color: enabled
            ? colors.textFillColorSecondary
            : colors.textFillColorDisabled,
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 1.2,
      ),
    );
  }
}

/// The surface owns the menu so hiding this button does not orphan the flyout.
class _PlaybackSettingsButton extends StatelessWidget {
  const _PlaybackSettingsButton({
    required this.player,
    required this.onPressed,
  });

  final Player player;
  final ValueChanged<BuildContext> onPressed;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: Platform.isWindows ? '播放设置：倍速、画幅、超分、音轨和字幕' : '播放设置：倍速、画幅、音轨和字幕',
    child: material.TextButton(
      key: const ValueKey('playback-settings'),
      style: material.TextButton.styleFrom(
        foregroundColor: Colors.white,
        minimumSize: const Size(64, 36),
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
      onPressed: () => onPressed(context),
      child: StreamBuilder<double>(
        stream: player.stream.rate,
        initialData: player.state.rate,
        builder: (_, rate) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${PlaybackRateMemory.label(rate.data ?? 1.0)}×',
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(width: 5),
            const Icon(material.Icons.settings_outlined, size: 18),
          ],
        ),
      ),
    ),
  );
}

List<MenuFlyoutItemBase> _playbackSettingsItems(
  Player player,
  PlaybackStore store,
  Future<void> Function(Future<void> Function()) run,
  Future<void> Function() pickSubtitle,
  Future<void> Function(PlaybackFit) setFit,
  ValueChanged<_PlaybackCommand> execute,
) => [
  MenuFlyoutSubItem(
    text: Text('播放速度 · ${PlaybackRateMemory.label(player.state.rate)}×'),
    items: (_) => [
      MenuFlyoutItem(
        text: Text(
          store.rememberedRate == null
              ? '1× / 记忆倍速切换'
              : '1× / ${PlaybackRateMemory.label(store.rememberedRate!)}× 切换',
        ),
        trailing: const _PlaybackMenuShortcut('Z'),
        onPressed: () => execute(_PlaybackCommand.toggleRate),
      ),
      MenuFlyoutItem(
        text: const Text('放慢 0.1×'),
        trailing: const _PlaybackMenuShortcut('X'),
        onPressed: () => execute(_PlaybackCommand.slower),
      ),
      MenuFlyoutItem(
        text: const Text('加速 0.1×'),
        trailing: const _PlaybackMenuShortcut('C'),
        onPressed: () => execute(_PlaybackCommand.faster),
      ),
      const MenuFlyoutSeparator(),
      for (var rate in [0.5, 0.75, 1.0, 1.25, 1.5, 2.0])
        ToggleMenuFlyoutItem(
          text: Text('${PlaybackRateMemory.label(rate)}×'),
          value: player.state.rate == rate,
          onChanged: (_) => unawaited(run(() => store.setRate(rate))),
        ),
    ],
  ),
  MenuFlyoutSubItem(
    text: Text('视频画幅 · ${store.fit.label}'),
    items: (_) => [
      for (var mode in PlaybackFit.values)
        ToggleMenuFlyoutItem(
          text: Text('${mode.label} · ${mode.description}'),
          value: store.fit == mode,
          onChanged: (_) => unawaited(run(() => setFit(mode))),
        ),
    ],
  ),
  if (Platform.isWindows)
    MenuFlyoutSubItem(
      text: Text('视频超分 · ${store.upscaleMode.label}'),
      items: (_) => [
        for (var mode in PlaybackUpscaleMode.values)
          ToggleMenuFlyoutItem(
            text: Text(
              mode == PlaybackUpscaleMode.light
                  ? '轻量 · Anime4K（SDR 放大）'
                  : mode.label,
            ),
            value: store.upscaleMode == mode,
            onChanged: (_) => unawaited(run(() => store.setUpscaleMode(mode))),
          ),
      ],
    ),
  MenuFlyoutSubItem(
    text: const Text('音轨'),
    items: (_) => [
      for (var track in player.state.tracks.audio)
        ToggleMenuFlyoutItem(
          text: Text(
            _playbackTrackLabel(track.id, track.title, track.language),
          ),
          value: player.state.track.audio.id == track.id,
          onChanged: (_) => unawaited(run(() => player.setAudioTrack(track))),
        ),
    ],
  ),
  MenuFlyoutSubItem(
    text: const Text('字幕轨道'),
    items: (_) => [
      for (var track in player.state.tracks.subtitle)
        ToggleMenuFlyoutItem(
          text: Text(
            _playbackTrackLabel(track.id, track.title, track.language),
          ),
          value: player.state.track.subtitle.id == track.id,
          onChanged: (_) =>
              unawaited(run(() => player.setSubtitleTrack(track))),
        ),
    ],
  ),
  const MenuFlyoutSeparator(),
  MenuFlyoutItem(
    text: const Text('加载外部字幕…'),
    leading: const Icon(material.Icons.subtitles_outlined, size: 16),
    onPressed: () => unawaited(run(pickSubtitle)),
  ),
];

BoxFit _playbackBoxFit(PlaybackFit mode) => switch (mode) {
  PlaybackFit.stretch => BoxFit.fill,
  PlaybackFit.tile => BoxFit.cover,
  PlaybackFit.fit => BoxFit.contain,
};

String _playbackTrackLabel(String id, String? title, String? language) {
  if (id == 'auto') return '自动选择';
  if (id == 'no') return '关闭';
  return [
    if (title != null && title.isNotEmpty) title,
    if (language != null && language.isNotEmpty) language,
    if ((title == null || title.isEmpty) &&
        (language == null || language.isEmpty))
      '轨道 $id',
  ].join(' · ');
}
