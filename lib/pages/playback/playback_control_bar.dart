part of 'playback_page.dart';

/// Control bar layout and video chrome; interaction state stays in the State.
extension _PlaybackControlBar on _PlaybackVideoControlsState {
  MaterialDesktopVideoControlsThemeData _controlsTheme(double width) {
    var store = widget.store;
    var player = widget.player;
    var item = store.current!;
    var label = ref.watch(playbackLabelProvider(item));
    var accent = FluentTheme.of(context).accentColor;
    // Reserve audio output and upscale buttons before adding optional controls.
    var bottomWidth = width - 52 - (Platform.isWindows ? 34 : 0);
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
          Builder(
            builder: (buttonContext) => _videoIconButton(
              _PlaybackOnTopIcon(
                onTop: widget.windowMode!.onTop,
                size: 20,
                color: Colors.white,
              ),
              _playbackOnTopTooltip(widget.windowMode!.onTop),
              () => unawaited(
                widget.run(
                  () => widget.windowMode!.setOnTop(
                    widget.windowMode!.onTop.next,
                  ),
                ),
              ),
              onLongPress: () => _showButtonMenu(
                buttonContext,
                () => _playbackOnTopItems(widget.windowMode!, widget.run),
                belowButton: true,
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
        if (Platform.isWindows)
          Builder(
            builder: (buttonContext) => _videoButton(
              material.Icons.auto_awesome_outlined,
              '超分配置 · ${store.upscaleMode.label}',
              () => _showButtonMenu(
                buttonContext,
                () => _playbackUpscaleItems(store, widget.run),
              ),
              key: const ValueKey('playback-upscale'),
              selected: store.upscaleMode != PlaybackUpscaleMode.off,
            ),
          ),
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
    VoidCallback? onLongPress,
  }) => Tooltip(
    message: tooltip,
    child: GestureDetector(
      onLongPress: onPressed == null ? null : onLongPress,
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
    ),
  );

  Widget _buildChrome(MaterialDesktopVideoControlsThemeData theme) => Stack(
    fit: StackFit.expand,
    children: [
      // Keep opacity and repaint bounds on the two bars. A full-stage group
      // can require a video-sized intermediate surface during every fade.
      for (var top in [true, false])
        Positioned(
          left: 0,
          right: 0,
          top: top ? 0 : null,
          bottom: top ? null : 0,
          child: IgnorePointer(
            ignoring: !_chromeVisible,
            child: AnimatedOpacity(
              opacity: _chromeVisible ? 1 : 0,
              duration: const Duration(milliseconds: 150),
              child: RepaintBoundary(
                child: Stack(
                  alignment: top ? Alignment.topCenter : Alignment.bottomCenter,
                  children: [
                    SizedBox(
                      width: double.infinity,
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
                              colors: const [
                                Color(0x99000000),
                                Color(0x00000000),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    SafeArea(
                      top: top,
                      bottom: !top,
                      child: MouseRegion(
                        onEnter: (_) => _hoverBar(true),
                        onExit: (_) => _hoverBar(false),
                        child: top
                            ? Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                child: SizedBox(
                                  height: 48,
                                  child: Row(children: theme.topButtonBar),
                                ),
                              )
                            : Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  RepaintBoundary(
                                    child: _PlaybackSeekBar(
                                      key: ValueKey(widget.store.current!.key),
                                      player: widget.player,
                                      visible: _chromeVisible,
                                      chapters: _availableChapters,
                                      onChapter: (chapter) => unawaited(
                                        widget.run(() => _seekChapter(chapter)),
                                      ),
                                      run: widget.run,
                                      onInteraction: _seekInteraction,
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    child: SizedBox(
                                      height: 48,
                                      child: Row(
                                        children: theme.bottomButtonBar,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ],
                ),
              ),
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
}
