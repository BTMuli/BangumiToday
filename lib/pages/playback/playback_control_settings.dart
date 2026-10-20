part of 'playback_page.dart';

/// Descriptions occupy their own line; long track names wrap within the menu.
class _PlaybackMenuLabel extends StatelessWidget {
  const _PlaybackMenuLabel(this.title, {this.description});

  final String title;
  final String? description;

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
            maxLines: 1,
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

List<MenuFlyoutItemBase> _playbackUpscaleItems(
  PlaybackStore store,
  Future<void> Function(Future<void> Function()) run,
) => [
  _playbackUpscaleItem(PlaybackUpscaleMode.off, store, run),
  for (var (title, isJanai) in [('Anime4K', false), ('JaNai', true)]) ...[
    MenuFlyoutItemBuilder(
      builder: (context) => Padding(
        // FlyoutListTile starts its content at 10 and reserves a 12px leading
        // slot plus a 10px gap for the check mark, so the header aligns with
        // the check mark by using that same 10px inset instead of the 32px
        // text inset. The vertical padding stays minimal: the heading row's
        // own height separates the groups, as options sit `vertical: 0` apart.
        padding: const EdgeInsets.fromLTRB(10, 4, 12, 2),
        child: Semantics(
          header: true,
          child: Text(title, style: BTTypography.caption(context)),
        ),
      ),
    ),
    for (var mode in PlaybackUpscaleMode.values)
      if (mode != PlaybackUpscaleMode.off && mode.isJanai == isJanai)
        _playbackUpscaleItem(mode, store, run),
  ],
];

MenuFlyoutItemBase _playbackUpscaleItem(
  PlaybackUpscaleMode mode,
  PlaybackStore store,
  Future<void> Function(Future<void> Function()) run,
) => MenuFlyoutItemBuilder(
  builder: (_) => ListenableBuilder(
    listenable: store,
    builder: (context, _) {
      var recommendation = mode.isJanai ? store.janaiRecommendation : null;
      var enabled = !mode.isJanai || store.tensorRtEnabled;
      return Tooltip(
        message: [
          mode.label,
          if (mode.description.isNotEmpty) mode.description,
          if (recommendation != null) recommendation.description(mode),
          if (!enabled) '请在应用设置 → 视频超分中启用 TensorRT',
        ].join('\n'),
        child: ToggleMenuFlyoutItem(
          text: Text(mode.label, maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: recommendation?.mode == mode
              ? const _PlaybackMenuShortcut('推荐')
              : null,
          value: store.upscaleMode == mode,
          onChanged: enabled
              ? (_) => unawaited(run(() => store.setUpscaleMode(mode)))
              : null,
        ).build(context),
      );
    },
  ),
);

List<MenuFlyoutItemBase> _playbackSettingsItems(
  Player player,
  PlaybackStore store,
  Future<void> Function(Future<void> Function()) run,
  Future<void> Function() pickSubtitle,
  ValueChanged<_PlaybackCommand> execute,
  PlaybackWindowMode? windowMode, {
  required bool includeUpscale,
}) => [
  MenuFlyoutSubItem(
    text: _PlaybackMenuLabel(
      '播放速度',
      description: '${PlaybackRateMemory.label(player.state.rate)}×',
    ),
    showBehavior: SubItemShowAction.press,
    items: (_) => _playbackRateItems(player, store, run, execute),
  ),
  if (includeUpscale && Platform.isWindows)
    MenuFlyoutSubItem(
      // fluent_ui 4.16.1 does not cancel its hover timer on disposal.
      showBehavior: SubItemShowAction.press,
      text: ListenableBuilder(
        listenable: store,
        builder: (_, _) =>
            _PlaybackMenuLabel('视频超分', description: store.upscaleMode.label),
      ),
      items: (_) => _playbackUpscaleItems(store, run),
    ),
  if (Platform.isWindows || Platform.isMacOS)
    MenuFlyoutSubItem(
      text: const Text('音频设置'),
      showBehavior: SubItemShowAction.press,
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
      text: _PlaybackMenuLabel('窗口置顶', description: windowMode.onTop.label),
      showBehavior: SubItemShowAction.press,
      items: (_) => _playbackOnTopItems(windowMode, run),
    ),
  MenuFlyoutSubItem(
    text: const Text('音轨'),
    showBehavior: SubItemShowAction.press,
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
    showBehavior: SubItemShowAction.press,
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
  for (var rate in [0.5, 1.0, 1.5, 2.0, 2.5, 3.0])
    ToggleMenuFlyoutItem(
      text: Text('${rate.toStringAsFixed(1)}×'),
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
  // The resolved row keeps "自动选择" as its title and shows the track it
  // resolved to on the second line, like "播放速度 / 1×", instead of joining
  // both into one title with " · ".
  if (selecting && track.id != 'auto') {
    return _PlaybackMenuLabel(
      '自动选择',
      description: playbackSubtitleTrackLabel(
        track.id,
        track.title,
        track.language,
      ),
    );
  }
  var label = playbackSubtitleLabel(track.id, track.title, track.language);
  return _PlaybackMenuLabel(label.title, description: label.description);
}
