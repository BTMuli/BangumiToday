part of 'playback_page.dart';

extension _PlaybackVideoControls on _PlaybackPageState {
  MaterialDesktopVideoControlsThemeData _controlsTheme(
    PlaybackStore store,
    double width,
  ) {
    var player = store.player!;
    var accent = FluentTheme.of(context).accentColor;
    return MaterialDesktopVideoControlsThemeData(
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
      bottomButtonBar: [
        if (width > 820)
          _videoButton(
            material.Icons.skip_previous_rounded,
            '上一个视频',
            store.index > 0 && !store.loading
                ? () => _run(() => store.jump(store.index - 1))
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
            () => _run(player.state.playing ? store.pause : player.play),
            key: const ValueKey('playback-toggle'),
          ),
        ),
        if (width > 820)
          _videoButton(
            material.Icons.skip_next_rounded,
            '下一个视频',
            store.index + 1 < store.playlist.length && !store.loading
                ? () => _run(() => store.jump(store.index + 1))
                : null,
          ),
        if (width > 700) ...[
          _videoButton(
            material.Icons.replay_10_rounded,
            '后退 10 秒',
            () => _run(() => _seekBy(player, -10)),
          ),
          _videoButton(
            material.Icons.forward_10_rounded,
            '前进 10 秒',
            () => _run(() => _seekBy(player, 10)),
          ),
        ],
        const MaterialDesktopVolumeButton(),
        const MaterialDesktopPositionIndicator(
          style: TextStyle(color: Colors.white, fontSize: 12),
        ),
        const Spacer(),
        _PlaybackSettingsButton(
          player: player,
          run: _run,
          pickSubtitle: _pickSubtitle,
        ),
        const MaterialDesktopFullscreenButton(),
      ],
    );
  }

  Widget _videoButton(
    IconData icon,
    String tooltip,
    VoidCallback? onPressed, {
    Key? key,
  }) => Tooltip(
    message: tooltip,
    child: material.IconButton(
      key: key,
      padding: const EdgeInsets.all(6),
      constraints: const BoxConstraints(minWidth: 34, minHeight: 36),
      iconSize: 22,
      color: Colors.white,
      disabledColor: Colors.white.withValues(alpha: 0.25),
      onPressed: onPressed,
      icon: Icon(icon),
    ),
  );

  Future<void> _seekBy(Player player, int seconds) async {
    var target = player.state.position + Duration(seconds: seconds);
    if (target < Duration.zero) target = Duration.zero;
    if (target > player.state.duration) target = player.state.duration;
    await player.seek(target);
  }
}

/// Each video surface owns its flyout, including the fullscreen surface.
class _PlaybackSettingsButton extends StatefulWidget {
  const _PlaybackSettingsButton({
    required this.player,
    required this.run,
    required this.pickSubtitle,
  });

  final Player player;
  final Future<void> Function(Future<void> Function()) run;
  final Future<void> Function() pickSubtitle;

  @override
  State<_PlaybackSettingsButton> createState() =>
      _PlaybackSettingsButtonState();
}

class _PlaybackSettingsButtonState extends State<_PlaybackSettingsButton> {
  final _flyout = FlyoutController();

  @override
  void dispose() {
    _flyout.dispose();
    super.dispose();
  }

  void _showSettings() {
    var player = widget.player;
    unawaited(
      _flyout.showFlyout(
        barrierDismissible: true,
        dismissOnPointerMoveAway: false,
        dismissWithEsc: true,
        builder: (context) => MenuFlyout(
          items: [
            MenuFlyoutSubItem(
              text: Text('播放速度 · ${player.state.rate}×'),
              items: (_) => [
                for (var rate in [0.5, 0.75, 1.0, 1.25, 1.5, 2.0])
                  ToggleMenuFlyoutItem(
                    text: Text('$rate×'),
                    value: player.state.rate == rate,
                    onChanged: (_) =>
                        unawaited(widget.run(() => player.setRate(rate))),
                  ),
              ],
            ),
            MenuFlyoutSubItem(
              text: const Text('音轨'),
              items: (_) => [
                for (var track in player.state.tracks.audio)
                  ToggleMenuFlyoutItem(
                    text: Text(
                      _trackLabel(track.id, track.title, track.language),
                    ),
                    value: player.state.track.audio.id == track.id,
                    onChanged: (_) => unawaited(
                      widget.run(() => player.setAudioTrack(track)),
                    ),
                  ),
              ],
            ),
            MenuFlyoutSubItem(
              text: const Text('字幕轨道'),
              items: (_) => [
                for (var track in player.state.tracks.subtitle)
                  ToggleMenuFlyoutItem(
                    text: Text(
                      _trackLabel(track.id, track.title, track.language),
                    ),
                    value: player.state.track.subtitle.id == track.id,
                    onChanged: (_) => unawaited(
                      widget.run(() => player.setSubtitleTrack(track)),
                    ),
                  ),
              ],
            ),
            const MenuFlyoutSeparator(),
            MenuFlyoutItem(
              text: const Text('加载外部字幕…'),
              leading: const Icon(material.Icons.subtitles_outlined, size: 16),
              onPressed: () => unawaited(widget.run(widget.pickSubtitle)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => FlyoutTarget(
    controller: _flyout,
    child: Tooltip(
      message: '播放设置：倍速、音轨和字幕',
      child: material.TextButton(
        key: const ValueKey('playback-settings'),
        style: material.TextButton.styleFrom(
          foregroundColor: Colors.white,
          minimumSize: const Size(64, 36),
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
        onPressed: _showSettings,
        child: StreamBuilder<double>(
          stream: widget.player.stream.rate,
          initialData: widget.player.state.rate,
          builder: (_, rate) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${rate.data ?? 1.0}×',
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(width: 5),
              const Icon(material.Icons.settings_outlined, size: 18),
            ],
          ),
        ),
      ),
    ),
  );

  static String _trackLabel(String id, String? title, String? language) {
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
}
