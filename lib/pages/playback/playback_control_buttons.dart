part of 'playback_page.dart';

/// 章节导航固定在列表上方，列表高度同时受菜单可用空间限制。
class _PlaybackChapterMenu extends StatelessWidget {
  const _PlaybackChapterMenu({
    required this.navigation,
    required this.chapters,
  });

  final List<MenuFlyoutItemBase> navigation;
  final List<MenuFlyoutItemBase> chapters;

  @override
  Widget build(BuildContext context) {
    var menu = context.findAncestorWidgetOfExactType<MenuFlyout>()!;
    // MenuFlyout gives its items unbounded height inside its scroll view.
    // Restore the menu's height budget so only the chapter list can scroll.
    var maxHeight =
        ((menu.constraints?.maxHeight ?? double.infinity) -
                kDefaultMenuPadding.vertical)
            .clamp(0.0, double.infinity);
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var item in navigation) item.build(context),
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: SingleChildScrollView(
                primary: false,
                physics: const ClampingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [for (var item in chapters) item.build(context)],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
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

String _playbackOnTopTooltip(PlaybackOnTop value) =>
    '窗口置顶：${value.label}（短按切换为${value.next.label}，长按选择模式）';

List<MenuFlyoutItemBase> _playbackOnTopItems(
  PlaybackWindowMode windowMode,
  Future<void> Function(Future<void> Function()) run,
) => [
  for (var mode in PlaybackOnTop.values)
    ToggleMenuFlyoutItem(
      text: _PlaybackMenuLabel(mode.label, description: mode.description),
      value: windowMode.onTop == mode,
      onChanged: (_) => unawaited(run(() => windowMode.setOnTop(mode))),
    ),
];

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
