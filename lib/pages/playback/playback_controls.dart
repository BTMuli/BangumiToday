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
    if (command == _PlaybackCommand.scaleHalf ||
        command == _PlaybackCommand.scaleOriginal ||
        command == _PlaybackCommand.scaleOneHalf) {
      await _applyWindowScale(command);
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
    if (store.loading || store.isOpening) {
      overlay.show(
        store.openingStatus ?? '正在加载视频…',
        material.Icons.hourglass_top_rounded,
      );
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
      case _PlaybackCommand.previousChapter:
      case _PlaybackCommand.nextChapter:
        var chapters = _availableChapters;
        var next = command == _PlaybackCommand.nextChapter;
        var chapter = adjacentPlaybackChapter(
          chapters,
          player.state.position,
          next: next,
        );
        if (chapter == null) {
          overlay.show(
            chapters.isEmpty
                ? '此视频没有章节信息'
                : next
                ? '已经是最后一个章节'
                : '已经是第一个章节',
            material.Icons.bookmark_outline_rounded,
          );
          return;
        }
        await _seekChapter(chapter);
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
          detail: PlaybackLabel.fromName(
            store.current!.title,
            filePath: store.current!.filePath,
          ).title,
        );
      case _PlaybackCommand.fullscreen:
      case _PlaybackCommand.escape:
      case _PlaybackCommand.info:
      case _PlaybackCommand.help:
      case _PlaybackCommand.scaleHalf:
      case _PlaybackCommand.scaleOriginal:
      case _PlaybackCommand.scaleOneHalf:
        return;
      case _PlaybackCommand.screenshot:
        await _copyScreenshot();
    }
  }

  List<PlaybackChapter> get _availableChapters {
    var duration = widget.player.state.duration;
    return [
      for (var chapter in widget.store.chapters)
        if (duration <= Duration.zero || chapter.start < duration) chapter,
    ];
  }

  Future<void> _seekChapter(PlaybackChapter chapter) async {
    if (widget.store.loading || !mounted) return;
    await widget.player.seek(chapter.start);
    widget.overlay.show(
      chapter.title,
      material.Icons.bookmark_outline_rounded,
      detail: _playbackTime(chapter.start),
    );
  }

  List<MenuFlyoutItemBase> _chapterItems() {
    var chapters = _availableChapters;
    var position = widget.player.state.position;
    var current = playbackChapterAt(chapters, position);
    return [
      for (var next in [false, true])
        MenuFlyoutItem(
          text: Text(next ? '下一章节' : '上一章节'),
          trailing: _PlaybackMenuShortcut(next ? 'D' : 'A'),
          onPressed:
              !widget.store.loading &&
                  adjacentPlaybackChapter(chapters, position, next: next) !=
                      null
              ? () => _execute(
                  next
                      ? _PlaybackCommand.nextChapter
                      : _PlaybackCommand.previousChapter,
                )
              : null,
        ),
      const MenuFlyoutSeparator(),
      for (var chapter in chapters)
        ToggleMenuFlyoutItem(
          text: Text('${_playbackTime(chapter.start)} · ${chapter.title}'),
          value: identical(chapter, current),
          onChanged: widget.store.loading
              ? null
              : (_) => unawaited(widget.run(() => _seekChapter(chapter))),
        ),
    ];
  }

  Future<void> _copyScreenshot() async {
    if (_takingScreenshot) return;
    _takingScreenshot = true;
    var overlay = widget.overlay;
    try {
      var screenshot = await widget.store.captureScreenshot();
      if (screenshot == null) return;
      var systemClipboard = clipboard.SystemClipboard.instance;
      if (systemClipboard == null) {
        throw const PlaybackUnavailable('当前平台不支持复制图片到剪贴板');
      }
      // The captured bytes remain valid after a playlist or controls change.
      var item = clipboard.DataWriterItem()
        ..add(clipboard.Formats.png(screenshot.image));
      await systemClipboard.write([item]);
      overlay.show(
        '截图已复制到剪贴板',
        material.Icons.photo_camera_outlined,
        detail: _playbackTime(screenshot.position),
      );
    } finally {
      _takingScreenshot = false;
    }
  }

  /// 数字键调整无边框窗口尺寸：1/2/3 对应视频像素的 0.5 / 1 / 1.5 倍。
  /// 2 倍在 1080p 上会超出工作区并被钳制，实测表现异常，因此不提供。
  Future<void> _applyWindowScale(_PlaybackCommand command) async {
    var mode = widget.windowMode;
    var overlay = widget.overlay;
    if (mode == null) {
      overlay.show(
        '当前窗口不支持调整尺寸',
        material.Icons.aspect_ratio_rounded,
        detail: '独立播放器窗口可按 1 / 2 / 3 调整',
      );
      return;
    }
    var (scale, label) = switch (command) {
      _PlaybackCommand.scaleHalf => (0.5, '0.5 倍'),
      _PlaybackCommand.scaleOneHalf => (1.5, '1.5 倍'),
      _ => (1.0, '原始像素'),
    };
    var fullscreen = isFullscreen(context);
    if (fullscreen) {
      overlay.closeMenus();
      // 原生退出回调与尺寸调整使用同一窗口操作队列，先恢复窗口再缩放。
      await exitFullscreen(context);
    }
    var base = mode.scaleBaseSize;
    var applied = await mode.setVideoScale(scale, center: fullscreen);
    if (applied == null) {
      overlay.show('暂时无法调整窗口尺寸', material.Icons.aspect_ratio_rounded);
      return;
    }
    var detail = mode.videoSize == null
        ? '未播放视频，按 ${base.width.round()} × ${base.height.round()} 基准'
        : '视频原始 ${base.width.round()} × ${base.height.round()}';
    if (applied.clamped) {
      detail =
          '屏幕可用区域不足，已限制为 '
          '${applied.size.width.round()} × ${applied.size.height.round()}';
    }
    overlay.show(
      '窗口尺寸 · $label',
      material.Icons.aspect_ratio_rounded,
      detail: detail,
    );
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
    var label = PlaybackLabel.fromName(item.title, filePath: item.filePath);
    var accent = FluentTheme.of(context).accentColor;
    // Reserve the audio output button before choosing optional controls.
    var bottomWidth = width - 52;
    // 独立播放器窗口只有视频，顶栏顺带承担拖动、置顶与窗口按钮。
    var frameless = widget.windowMode != null && !isFullscreen(context);
    return MaterialDesktopVideoControlsThemeData(
      buttonBarHeight: 48,
      buttonBarButtonSize: 20,
      volumeBarActiveColor: accent,
      volumeBarThumbColor: accent,
      topButtonBar: [
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            // 自绘拖动：系统移动循环无法在拖动过程中限制窗口位置。
            onPanStart: frameless
                ? (_) => unawaited(widget.run(widget.windowMode!.beginDrag))
                : null,
            onPanUpdate: frameless
                ? (_) => unawaited(widget.windowMode!.updateDrag())
                : null,
            onPanEnd: frameless
                ? (_) => unawaited(widget.run(widget.windowMode!.endDrag))
                : null,
            onPanCancel: frameless
                ? () => unawaited(widget.run(widget.windowMode!.endDrag))
                : null,
            child: Tooltip(
              message: item.title,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    store.nameFor(item.subject) ?? label.title,
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
        ),
        if (width > 360) ...[
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
        Builder(
          builder: (buttonContext) => _videoButton(
            material.Icons.settings_outlined,
            '播放设置',
            () => _showSettings(buttonContext),
            key: const ValueKey('playback-settings'),
          ),
        ),
        if (frameless) ...[
          _videoIconButton(
            _PlaybackOnTopIcon(
              onTop: widget.windowMode!.onTop,
              size: 20,
              color: Colors.white,
            ),
            _playbackOnTopTooltip(widget.windowMode!.onTop),
            () => unawaited(
              widget.run(
                () =>
                    widget.windowMode!.setOnTop(widget.windowMode!.onTop.next),
              ),
            ),
          ),
          _videoButton(
            material.Icons.remove_rounded,
            '最小化',
            () => unawaited(widget.run(widget.windowMode!.minimize)),
          ),
          _videoButton(
            material.Icons.close_rounded,
            '关闭播放器',
            () => unawaited(widget.run(widget.windowMode!.closeWindow)),
          ),
        ],
      ],
      bottomButtonBar: [
        if (bottomWidth > 420)
          const RepaintBoundary(
            child: MaterialDesktopPositionIndicator(
              style: TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        if (bottomWidth > 420) const SizedBox(width: 12),
        if (bottomWidth > 820)
          _videoButton(
            material.Icons.skip_previous_rounded,
            '上一个视频',
            store.index > 0 && !store.loading && !store.isOpening
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
        if (bottomWidth > 820)
          _videoButton(
            material.Icons.skip_next_rounded,
            '下一个视频',
            store.index + 1 < store.playlist.length &&
                    !store.loading &&
                    !store.isOpening
                ? () => _execute(_PlaybackCommand.next)
                : null,
          ),
        if (bottomWidth > 700) ...[
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
        if (bottomWidth > 620) const MaterialDesktopVolumeButton(),
        const Spacer(),
        if (store.chapters.isNotEmpty)
          Builder(
            builder: (buttonContext) => _videoButton(
              material.Icons.bookmarks_outlined,
              '章节（A / D）',
              () => _showButtonMenu(buttonContext, _chapterItems),
            ),
          ),
        if (bottomWidth > 340)
          _PlaybackRateButton(player: player, onPressed: _showRateMenu),
        _PlaybackHiResButton(
          store: store,
          onPressed: () => unawaited(
            widget.run(() => store.setHiResEnabled(!store.hiResEnabled)),
          ),
        ),
        // 内嵌播放页已有侧栏时不重复提供选集/记录入口。
        if (!widget.sidebarVisible) ...[
          Builder(
            builder: (buttonContext) => _videoButton(
              material.Icons.playlist_play_rounded,
              '选集',
              () =>
                  _showLibrary(buttonContext, _PlaybackLibrarySection.playlist),
            ),
          ),
          Builder(
            builder: (buttonContext) => _videoButton(
              material.Icons.history_rounded,
              '播放记录',
              () =>
                  _showLibrary(buttonContext, _PlaybackLibrarySection.history),
            ),
          ),
        ],
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
  }) => _videoIconButton(
    Icon(icon),
    tooltip,
    onPressed,
    key: key,
    selected: selected,
  );

  Widget _videoIconButton(
    Widget icon,
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
      icon: icon,
    ),
  );

  List<MenuFlyoutItemBase> _settingsItems() => [
    ..._playbackSettingsItems(
      widget.player,
      widget.store,
      widget.run,
      widget.pickSubtitle,
      _execute,
      widget.windowMode,
    ),
    // 无边框播放器窗口没有标题栏入口，来源操作放在设置与右键菜单里。
    const MenuFlyoutSeparator(),
    MenuFlyoutItem(
      text: const Text('打开本地视频…'),
      leading: const Icon(material.Icons.video_file_outlined, size: 16),
      onPressed: () => unawaited(widget.run(widget.pickFile)),
    ),
    MenuFlyoutItem(
      text: const Text('停止播放'),
      leading: const Icon(material.Icons.stop_circle_outlined, size: 16),
      onPressed: () => unawaited(widget.run(widget.stopPlayback)),
    ),
  ];

  void _showSettings(BuildContext buttonContext) =>
      _showButtonMenu(buttonContext, _settingsItems, belowButton: true);

  void _showRateMenu(BuildContext buttonContext) => _showButtonMenu(
    buttonContext,
    () => _playbackRateItems(widget.player, widget.store, widget.run, _execute),
    menuWidth: 220,
  );

  void _showButtonMenu(
    BuildContext buttonContext,
    List<MenuFlyoutItemBase> Function() items, {
    bool belowButton = false,
    double menuWidth = 320,
  }) {
    var navigatorBox =
        Navigator.of(context).context.findRenderObject() as RenderBox;
    var buttonBox = buttonContext.findRenderObject() as RenderBox;
    var layout = _playbackLibraryFlyoutLayout(
      buttonContext: buttonContext,
      navigatorBox: navigatorBox,
      preferBelow: belowButton,
      maximumWidth: menuWidth,
    );
    var button = buttonBox.localToGlobal(Offset.zero, ancestor: navigatorBox);
    var above = layout.position.dy < button.dy;
    // Explicit placement and height constraints prevent the flyout's automatic
    // edge clamping from moving a tall speed menu back over its trigger.
    var position = above
        ? Offset(layout.position.dx, button.dy - 8)
        : layout.position;
    _showMenu(
      position,
      items,
      placement: above
          ? FlyoutPlacementMode.topLeft
          : FlyoutPlacementMode.bottomLeft,
      constraints: BoxConstraints(
        minWidth: layout.size.width,
        maxWidth: layout.size.width,
        maxHeight: layout.size.height,
      ),
    );
  }

  /// 选集与播放记录各自浮出独立内容，按按钮上方的空间限制面板高度。
  void _showLibrary(
    BuildContext buttonContext,
    _PlaybackLibrarySection section,
  ) {
    widget.overlay.closeMenus();
    _showChrome();
    _hideTimer?.cancel();
    var navigatorBox =
        Navigator.of(context).context.findRenderObject() as RenderBox;
    var layout = _playbackLibraryFlyoutLayout(
      buttonContext: buttonContext,
      navigatorBox: navigatorBox,
    );
    unawaited(
      widget.run(() async {
        try {
          await _contextMenu.showFlyout<void>(
            placementMode: FlyoutPlacementMode.bottomLeft,
            position: layout.position,
            builder: (_) => _playbackLibraryFlyout(
              widget.buildLibraryPanel(section),
              layout.size,
            ),
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

  void _showMenu(
    Offset position,
    List<MenuFlyoutItemBase> Function() items, {
    FlyoutPlacementMode placement = FlyoutPlacementMode.auto,
    BoxConstraints? constraints,
  }) {
    _showChrome();
    _hideTimer?.cancel();
    var navigatorBox =
        Navigator.of(context).context.findRenderObject() as RenderBox;
    var maximumWidth = (navigatorBox.size.width - 16).clamp(0.0, 320.0);
    var menuConstraints =
        constraints ??
        BoxConstraints(
          minWidth: maximumWidth.clamp(0.0, 220.0),
          maxWidth: maximumWidth,
          maxHeight: (navigatorBox.size.height - 16).clamp(
            0.0,
            double.infinity,
          ),
        );
    unawaited(
      widget.run(() async {
        try {
          // Only suppress motion for an installed upscale shader chain. Set
          // transitions on the route so the root and all submenus inherit them.
          var upscaling = widget.store.upscaler?.configuredMode != null;
          await _contextMenu.showFlyout<void>(
            position: position,
            placementMode: placement,
            transitionDuration: upscaling ? Duration.zero : null,
            transitionBuilder: upscaling ? (_, _, _, child) => child : null,
            // FlyoutContent.useAcrylic only changes tint opacity in fluent_ui
            // 4.16.1. DisableAcrylic removes the actual video backdrop filter
            // and MenuFlyout carries it into every submenu's overlay entry.
            builder: (_) => DisableAcrylic(
              child: RepaintBoundary(
                child: MenuFlyout(items: items(), constraints: menuConstraints),
              ),
            ),
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
          leading: Icon(
            player.state.playing
                ? material.Icons.pause_rounded
                : material.Icons.play_arrow_rounded,
            size: 16,
          ),
          trailing: const _PlaybackMenuShortcut('Space / K'),
          onPressed: () => _execute(_PlaybackCommand.toggle),
        ),
        MenuFlyoutSubItem(
          text: const Text('播放与跳转'),
          leading: const Icon(material.Icons.playlist_play_rounded, size: 16),
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
        if (widget.store.chapters.isNotEmpty)
          MenuFlyoutSubItem(
            text: const Text('章节'),
            leading: const Icon(material.Icons.bookmarks_outlined, size: 16),
            items: (_) => _chapterItems(),
          ),
        MenuFlyoutSubItem(
          text: const Text('播放设置'),
          leading: const Icon(material.Icons.settings_outlined, size: 16),
          items: (_) => _settingsItems(),
        ),
        MenuFlyoutItem(
          text: const Text('截屏并复制到剪贴板'),
          leading: const Icon(material.Icons.photo_camera_outlined, size: 16),
          trailing: const _PlaybackMenuShortcut('S'),
          onPressed: () => _execute(_PlaybackCommand.screenshot),
        ),
        const MenuFlyoutSeparator(),
        ToggleMenuFlyoutItem(
          text: const Text('视频信息覆盖层'),
          trailing: const _PlaybackMenuShortcut('Tab'),
          value: overlay.showInfo,
          onChanged: (_) => _execute(_PlaybackCommand.info),
        ),
        MenuFlyoutItem(
          text: const Text('查看快捷键'),
          leading: const Icon(material.Icons.keyboard_alt_outlined, size: 16),
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
                          RepaintBoundary(
                            child: _PlaybackSeekBar(
                              key: ValueKey(widget.store.current!.key),
                              player: widget.player,
                              chapters: _availableChapters,
                              onChapter: (chapter) => unawaited(
                                widget.run(() => _seekChapter(chapter)),
                              ),
                              run: widget.run,
                              onInteraction: _seekInteraction,
                            ),
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
          builder: (_, snapshot) {
            var status = widget.store.openingStatus;
            if (status != null) {
              return _PlaybackLoadingIndicator(
                message: status,
                filePath: widget.store.openingFile,
              );
            }
            return snapshot.data == true
                ? const _PlaybackLoadingIndicator(message: '正在缓冲视频…')
                : const SizedBox.shrink();
          },
        ),
      ),
    ],
  );

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
                                  widget.store.upscaleMode.isJanai &&
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

/// 三态置顶图标：关闭空心、播放时空心加播放角标、始终置顶实心。
class _PlaybackOnTopIcon extends StatelessWidget {
  const _PlaybackOnTopIcon({required this.onTop, this.size = 19, this.color});

  final PlaybackOnTop onTop;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    var tint = onTop.pinned
        ? FluentTheme.of(context).accentColor
        : color ?? FluentTheme.of(context).accentColor;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Icon(
            onTop == PlaybackOnTop.always
                ? material.Icons.push_pin
                : material.Icons.push_pin_outlined,
            size: size,
            color: tint,
          ),
          if (onTop == PlaybackOnTop.playing)
            Positioned(
              right: -1,
              bottom: -1,
              child: Icon(
                material.Icons.play_arrow_rounded,
                size: size * 0.55,
                color: tint,
              ),
            ),
        ],
      ),
    );
  }
}

String _playbackOnTopTooltip(PlaybackOnTop value) => switch (value) {
  PlaybackOnTop.off =>
    '窗口置顶：${PlaybackOnTop.off.label}（点击切换为${PlaybackOnTop.playing.label}）',
  PlaybackOnTop.playing =>
    '窗口置顶：${PlaybackOnTop.playing.label}（点击切换为'
        '${PlaybackOnTop.always.label}）',
  PlaybackOnTop.always => '窗口置顶：${PlaybackOnTop.always.label}（点击关闭置顶）',
};

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

/// A quick rate picker; all playback options are available in the top bar.
class _PlaybackRateButton extends StatelessWidget {
  const _PlaybackRateButton({required this.player, required this.onPressed});

  final Player player;
  final ValueChanged<BuildContext> onPressed;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: '播放速度',
    child: material.TextButton(
      key: const ValueKey('playback-rate'),
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
            const Icon(material.Icons.speed_rounded, size: 18),
          ],
        ),
      ),
    ),
  );
}

class _PlaybackHiResButton extends StatelessWidget {
  const _PlaybackHiResButton({required this.store, required this.onPressed});

  final PlaybackStore store;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    var hiRes = store.hiRes;
    var clickable = hiRes.available || hiRes.requested;
    var color = hiRes.active
        ? FluentTheme.of(context).accentColor
        : hiRes.requested && hiRes.available
        ? const Color(0xFFFFE27A)
        : Colors.white.withValues(alpha: clickable ? 1 : 0.4);
    return Tooltip(
      message: hiRes.tooltip,
      child: Semantics(
        label: hiRes.status,
        toggled: hiRes.requested,
        child: material.TextButton(
          key: const ValueKey('playback-hires'),
          style: material.TextButton.styleFrom(
            foregroundColor: color,
            disabledForegroundColor: color,
            backgroundColor: hiRes.active
                ? color.withValues(alpha: 0.15)
                : Colors.transparent,
            minimumSize: const Size(52, 36),
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
          onPressed: clickable ? onPressed : null,
          child: const Text(
            'HiRes',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}

/// Descriptions occupy their own line; long track names wrap within the menu.
class _PlaybackMenuLabel extends StatelessWidget {
  const _PlaybackMenuLabel(
    this.title, {
    this.description,
    this.descriptionMaxLines = 1,
  });

  final String title;
  final String? description;
  final int descriptionMaxLines;

  @override
  Widget build(BuildContext context) {
    var detail = description;
    var color = DefaultTextStyle.of(context).style.color;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: detail == null ? 2 : 1,
          softWrap: true,
          overflow: TextOverflow.ellipsis,
        ),
        if (detail != null) ...[
          const SizedBox(height: 2),
          Text(
            detail,
            maxLines: descriptionMaxLines,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: color?.withValues(alpha: color.a * 0.7),
            ),
          ),
        ],
      ],
    );
  }
}

Widget _playbackJanaiMenuLabel(
  PlaybackStore store, {
  required PlaybackUpscaleMode mode,
}) => ListenableBuilder(
  listenable: store,
  builder: (_, _) {
    var recommendation = store.janaiRecommendation;
    return _PlaybackMenuLabel(
      '${mode.label}${mode == recommendation.mode ? ' · 推荐' : ''}',
      description: '${mode.description}\n${recommendation.description(mode)}',
      descriptionMaxLines: 3,
    );
  },
);

List<MenuFlyoutItemBase> _playbackSettingsItems(
  Player player,
  PlaybackStore store,
  Future<void> Function(Future<void> Function()) run,
  Future<void> Function() pickSubtitle,
  ValueChanged<_PlaybackCommand> execute,
  PlaybackWindowMode? windowMode,
) => [
  MenuFlyoutSubItem(
    text: Text('播放速度 · ${PlaybackRateMemory.label(player.state.rate)}×'),
    items: (_) => _playbackRateItems(player, store, run, execute),
  ),
  if (Platform.isWindows)
    MenuFlyoutSubItem(
      text: ListenableBuilder(
        listenable: store,
        builder: (_, _) => Text('视频超分 · ${store.upscaleMode.label}'),
      ),
      items: (_) {
        return [
          ToggleMenuFlyoutItem(
            text: _PlaybackMenuLabel(
              '启用 TensorRT',
              description: store.tensorRtResources.configurationHint,
            ),
            value: store.tensorRtEnabled,
            onChanged:
                store.tensorRtResources.canEnable || store.tensorRtEnabled
                ? (enabled) =>
                      unawaited(run(() => store.setTensorRtEnabled(enabled)))
                : null,
          ),
          const MenuFlyoutSeparator(),
          for (var mode in PlaybackUpscaleMode.values)
            MenuFlyoutItemBuilder(
              builder: (_) => ListenableBuilder(
                listenable: store,
                builder: (context, _) => ToggleMenuFlyoutItem(
                  text: mode.isJanai
                      ? _playbackJanaiMenuLabel(store, mode: mode)
                      : _PlaybackMenuLabel(
                          mode.label,
                          description: mode == PlaybackUpscaleMode.off
                              ? null
                              : mode.description,
                        ),
                  value: store.upscaleMode == mode,
                  onChanged:
                      mode.isJanai &&
                          (!store.tensorRtEnabled ||
                              !store.tensorRtResources.canEnable)
                      ? null
                      : (_) => unawaited(run(() => store.setUpscaleMode(mode))),
                ).build(context),
              ),
            ),
        ];
      },
    ),
  if (Platform.isWindows || Platform.isMacOS)
    MenuFlyoutSubItem(
      text: const Text('音频设置'),
      items: (_) => [
        if (Platform.isWindows)
          ToggleMenuFlyoutItem(
            text: _PlaybackMenuLabel(
              '响度均衡',
              description: store.loudnessPausedForHiRes ? 'HiRes 输出下暂停' : null,
            ),
            value: store.loudnessEnabled,
            onChanged: store.loudnessPausedForHiRes
                ? null
                : (enabled) =>
                      unawaited(run(() => store.setLoudnessEnabled(enabled))),
          ),
        ToggleMenuFlyoutItem(
          text: _PlaybackMenuLabel(
            '独占输出',
            description: store.canEnableAudioExclusive
                ? '保持源格式，会影响其他应用声音'
                : '开启 HiRes 后可用',
          ),
          value: store.audioExclusiveEnabled,
          onChanged: store.canEnableAudioExclusive
              ? (enabled) => unawaited(
                  run(() => store.setAudioExclusiveEnabled(enabled)),
                )
              : null,
        ),
      ],
    ),
  if (windowMode != null)
    MenuFlyoutSubItem(
      text: Text('窗口置顶 · ${windowMode.onTop.label}'),
      items: (_) => [
        for (var mode in PlaybackOnTop.values)
          ToggleMenuFlyoutItem(
            text: _PlaybackMenuLabel(mode.label, description: mode.description),
            value: windowMode.onTop == mode,
            onChanged: (_) => unawaited(run(() => windowMode.setOnTop(mode))),
          ),
      ],
    ),
  MenuFlyoutSubItem(
    text: const Text('音轨'),
    items: (_) => [
      for (var track in player.state.tracks.audio)
        ToggleMenuFlyoutItem(
          text: _PlaybackMenuLabel(
            _playbackTrackLabel(track.id, track.title, track.language),
          ),
          value: player.state.track.audio.id == track.id,
          onChanged: (_) => unawaited(run(() => store.setAudioTrack(track))),
        ),
    ],
  ),
  MenuFlyoutSubItem(
    text: const Text('字幕轨道'),
    items: (_) => [
      for (var track in player.state.tracks.subtitle)
        ToggleMenuFlyoutItem(
          text: _playbackSubtitleMenuLabel(
            player,
            track,
            automatic: store.automaticSubtitles,
          ),
          value: track.id == 'auto'
              ? store.automaticSubtitles
              : !store.automaticSubtitles &&
                    player.state.track.subtitle.id == track.id,
          onChanged: (_) => unawaited(run(() => store.setSubtitleTrack(track))),
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

List<MenuFlyoutItemBase> _playbackRateItems(
  Player player,
  PlaybackStore store,
  Future<void> Function(Future<void> Function()) run,
  ValueChanged<_PlaybackCommand> execute,
) => [
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
];

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

Widget _playbackSubtitleMenuLabel(
  Player player,
  SubtitleTrack track, {
  required bool automatic,
}) {
  var selecting = track.id == 'auto' && automatic;
  if (selecting) {
    track = player.state.tracks.subtitle.firstWhere(
      (track) => track.id == player.state.track.subtitle.id,
      orElse: () => player.state.track.subtitle,
    );
  }
  var label = playbackSubtitleLabel(track.id, track.title, track.language);
  return _PlaybackMenuLabel(
    selecting && track.id != 'auto' ? '自动选择 · ${label.title}' : label.title,
    description: label.description,
  );
}
