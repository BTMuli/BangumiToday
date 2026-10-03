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
  StreamSubscription<double>? _volumeSubscription;

  @override
  void initState() {
    super.initState();
    widget.overlay.menuClosers.add(_closeMenu);
    var volume = widget.player.state.volume;
    if (volume > 0) widget.overlay.audibleVolume = volume;
    _volumeSubscription = widget.player.stream.volume.listen((value) {
      if (value > 0) widget.overlay.audibleVolume = value;
    });
  }

  bool _closeMenu() {
    if (!_contextMenu.isOpen) return false;
    _contextMenu.forceClose();
    return true;
  }

  @override
  void dispose() {
    widget.overlay.menuClosers.remove(_closeMenu);
    unawaited(_volumeSubscription?.cancel());
    _contextMenu.dispose();
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
    if (command == _PlaybackCommand.info) {
      overlay.toggleInfo();
      return;
    }
    if (command == _PlaybackCommand.help) {
      overlay.toggleHelp();
      if (!overlay.showHelp) _focusVideo();
      return;
    }
    if (command == _PlaybackCommand.escape) {
      if (overlay.showHelp) {
        overlay.toggleHelp();
        _focusVideo();
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
        var rate =
            (player.state.rate +
                    (command == _PlaybackCommand.faster ? 0.25 : -0.25))
                .clamp(0.25, 3.0);
        await player.setRate(rate);
        overlay.show('播放速度 $rate×', material.Icons.speed_rounded);
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
    }
  }

  void _focusVideo() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.video.widget.focusNode?.requestFocus();
    });
  }

  MaterialDesktopVideoControlsThemeData _controlsTheme(double width) {
    var store = widget.store;
    var player = widget.player;
    var item = store.current!;
    var label = PlaybackLabel.fromName(item.title);
    var accent = FluentTheme.of(context).accentColor;
    return MaterialDesktopVideoControlsThemeData(
      // The outer shortcut scope also contains our overlay panels.
      keyboardShortcuts: const {},
      visibleOnMount: true,
      hideMouseOnControlsRemoval: true,
      buttonBarHeight: 48,
      buttonBarButtonSize: 20,
      bottomButtonBarMargin: const EdgeInsets.symmetric(horizontal: 12),
      seekBarMargin: const EdgeInsets.symmetric(horizontal: 16),
      seekBarPositionColor: accent,
      seekBarThumbColor: accent,
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
    unawaited(
      _contextMenu.showFlyout<void>(
        position: buttonBox.localToGlobal(Offset.zero, ancestor: navigatorBox),
        builder: (_) => MenuFlyout(
          items: _playbackSettingsItems(
            widget.player,
            widget.run,
            widget.pickSubtitle,
          ),
        ),
      ),
    );
  }

  void _showContextMenu(TapUpDetails details) {
    var navigator = Navigator.of(context);
    var box = navigator.context.findRenderObject() as RenderBox;
    var player = widget.player;
    var overlay = widget.overlay;
    unawaited(
      _contextMenu.showFlyout<void>(
        position: box.globalToLocal(details.globalPosition),
        builder: (_) => MenuFlyout(
          items: [
            MenuFlyoutItem(
              text: Text(player.state.playing ? '暂停' : '继续播放'),
              trailing: const Text('Space'),
              onPressed: () => _execute(_PlaybackCommand.toggle),
            ),
            MenuFlyoutSubItem(
              text: const Text('播放与跳转'),
              items: (_) => [
                MenuFlyoutItem(
                  text: const Text('后退 10 秒'),
                  trailing: const Text('J'),
                  onPressed: () => _execute(_PlaybackCommand.back10),
                ),
                MenuFlyoutItem(
                  text: const Text('前进 10 秒'),
                  trailing: const Text('L / I'),
                  onPressed: () => _execute(_PlaybackCommand.forward10),
                ),
                const MenuFlyoutSeparator(),
                MenuFlyoutItem(
                  text: const Text('上一个视频'),
                  trailing: const Text('Page Up'),
                  onPressed: widget.store.index > 0
                      ? () => _execute(_PlaybackCommand.previous)
                      : null,
                ),
                MenuFlyoutItem(
                  text: const Text('下一个视频'),
                  trailing: const Text('Page Down'),
                  onPressed:
                      widget.store.index + 1 < widget.store.playlist.length
                      ? () => _execute(_PlaybackCommand.next)
                      : null,
                ),
              ],
            ),
            ToggleMenuFlyoutItem(
              text: const Text('静音'),
              trailing: const Text('M'),
              value: player.state.volume == 0,
              onChanged: (_) => _execute(_PlaybackCommand.mute),
            ),
            const MenuFlyoutSeparator(),
            ..._playbackSettingsItems(player, widget.run, widget.pickSubtitle),
            const MenuFlyoutSeparator(),
            MenuFlyoutItem(
              text: Text(isFullscreen(context) ? '退出全屏' : '进入全屏'),
              trailing: const Text('F / Enter'),
              onPressed: () => _execute(_PlaybackCommand.fullscreen),
            ),
            ToggleMenuFlyoutItem(
              text: const Text('视频信息覆盖层'),
              trailing: const Text('Tab'),
              value: overlay.showInfo,
              onChanged: (_) => _execute(_PlaybackCommand.info),
            ),
            MenuFlyoutItem(
              text: const Text('查看快捷键'),
              trailing: const Text('F1'),
              onPressed: () => _execute(_PlaybackCommand.help),
            ),
          ],
        ),
      ),
    );
  }

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
              child: material.Theme(
                data: material.ThemeData.dark(),
                child: FlyoutTarget(
                  controller: _contextMenu,
                  child: Listener(
                    onPointerDown: (_) {
                      if (!widget.overlay.showHelp) {
                        widget.video.widget.focusNode?.requestFocus();
                      }
                    },
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onSecondaryTapUp: _showContextMenu,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          MaterialDesktopVideoControlsTheme(
                            normal: theme,
                            fullscreen: theme,
                            child: MaterialDesktopVideoControls(widget.video),
                          ),
                          if (widget.overlay.showInfo)
                            Positioned.fill(
                              left: 16,
                              right: 16,
                              top: constraints.maxHeight >= 300 ? 64 : 8,
                              bottom: constraints.maxHeight >= 300 ? 92 : 8,
                              child: IgnorePointer(
                                child: _PlaybackVideoInfo(
                                  key: ValueKey(item.key),
                                  player: widget.player,
                                  item: item,
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
                                onClose: () => _execute(_PlaybackCommand.help),
                              ),
                            ),
                        ],
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
    message: '播放设置：倍速、音轨和字幕',
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
            Text('${rate.data ?? 1.0}×', style: const TextStyle(fontSize: 12)),
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
  Future<void> Function(Future<void> Function()) run,
  Future<void> Function() pickSubtitle,
) => [
  MenuFlyoutSubItem(
    text: Text('播放速度 · ${player.state.rate}×'),
    items: (_) => [
      for (var rate in [0.5, 0.75, 1.0, 1.25, 1.5, 2.0])
        ToggleMenuFlyoutItem(
          text: Text('$rate×'),
          value: player.state.rate == rate,
          onChanged: (_) => unawaited(run(() => player.setRate(rate))),
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
