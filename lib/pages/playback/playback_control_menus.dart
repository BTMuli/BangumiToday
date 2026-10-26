part of 'playback_page.dart';

/// Flyout placement, context menu and chapter navigation.
extension _PlaybackControlMenus on _PlaybackVideoControlsState {
  List<MenuFlyoutItemBase> _chapterItems() {
    var chapters = _availableChapters;
    var position = widget.player.state.position;
    var current = playbackChapterAt(chapters, position);
    var navigation = <MenuFlyoutItemBase>[
      for (var next in [false, true])
        MenuFlyoutItem(
          text: Text(next ? '下一章节' : '上一章节'),
          leading: const Icon(null),
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
    ];
    return [
      MenuFlyoutItemBuilder(
        builder: (_) => _PlaybackChapterMenu(
          navigation: navigation,
          chapters: [
            for (var chapter in chapters)
              ToggleMenuFlyoutItem(
                text: Text(
                  '${_playbackTime(chapter.start)} · ${chapter.title}',
                ),
                value: identical(chapter, current),
                onChanged: widget.store.loading
                    ? null
                    : (_) => unawaited(widget.run(() => _seekChapter(chapter))),
              ),
          ],
        ),
      ),
    ];
  }

  List<MenuFlyoutItemBase> _settingsItems({bool includeUpscale = true}) => [
    ..._playbackSettingsItems(
      widget.player,
      widget.store,
      widget.run,
      widget.pickSubtitle,
      _execute,
      widget.windowMode,
      includeUpscale: includeUpscale,
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
  );

  void _showButtonMenu(
    BuildContext buttonContext,
    List<MenuFlyoutItemBase> Function() items, {
    bool belowButton = false,
  }) {
    var navigatorBox =
        Navigator.of(context).context.findRenderObject() as RenderBox;
    var buttonBox = buttonContext.findRenderObject() as RenderBox;
    // Only the height cap and the side come from the layout; the width follows
    // the shared menu rule.
    var layout = _playbackLibraryFlyoutLayout(
      buttonContext: buttonContext,
      navigatorBox: navigatorBox,
      preferBelow: belowButton,
    );
    var button =
        buttonBox.localToGlobal(Offset.zero, ancestor: navigatorBox) &
        buttonBox.size;
    var above = layout.position.dy < button.top;
    // The menu follows its own content width, so the center placement modes
    // have to center — and clamp — on the width measured at layout time.
    // Keeping the height cap still prevents the flyout's automatic edge
    // clamping from moving a tall menu back over its trigger.
    _showMenu(
      Offset(button.center.dx, above ? button.top - 8 : button.bottom + 8),
      items,
      placement: above
          ? FlyoutPlacementMode.topCenter
          : FlyoutPlacementMode.bottomCenter,
      constraints: _playbackMenuConstraints(
        navigatorBox,
        maxHeight: layout.size.height,
      ),
    );
  }

  /// One width policy for every playback menu — the context menu, the button
  /// menus and the bottom bar entries — since the same list would otherwise
  /// come out at different widths depending on where it was opened. The flyout
  /// follows its content between the floor and the cap, and submenus inherit
  /// the result through `MenuFlyout.constraints`.
  BoxConstraints _playbackMenuConstraints(
    RenderBox navigatorBox, {
    required double maxHeight,
  }) {
    var navigator = navigatorBox.size;
    return BoxConstraints(
      minWidth: _PlaybackVideoControlsState._playbackMenuMinWidth,
      maxWidth:
          (navigator.width -
                  2 * _PlaybackVideoControlsState._playbackMenuMargin)
              .clamp(
                _PlaybackVideoControlsState._playbackMenuMinWidth,
                _PlaybackVideoControlsState._playbackMenuMaxWidth,
              ),
      maxHeight: maxHeight,
    );
  }

  /// 播放窗口浮出层统一入口。超分实际生效时省去过场动画：动画帧会与
  /// 超分渲染争用 GPU 预算，而菜单与选集面板本就需要稳定尺寸才可阅读。
  Future<T?> _showPlaybackFlyout<T>({
    required Offset position,
    required FlyoutPlacementMode placement,
    required WidgetBuilder builder,
  }) => _contextMenu.showFlyout<T>(
    position: position,
    placementMode: placement,
    // Set the transitions on the route: the root menu and every submenu
    // inherit them through `Flyout.of`.
    transitionDuration: _upscalingActive ? Duration.zero : null,
    transitionBuilder: _upscalingActive ? (_, _, _, child) => child : null,
    builder: builder,
  );

  /// 着色器链或 AI 滤镜已实际安装。只按“已选择”判断会把回退到普通播放的
  /// 场景也算作超分，所以这里依据配置成功的状态。
  bool get _upscalingActive => widget.store.upscaler?.configuredMode != null;

  /// 选集与播放记录各自浮出独立内容。选集按列表内容收缩，切换排版时同步
  /// 调整高度；记录页保持最大高度。两者都受按钮上方的可用空间限制。
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
    // 面板宽度与外层定位盒相差 FlyoutContent 的 1px 描边。
    var box = Size(
      layout.size.width + _playbackFlyoutBorder,
      layout.size.height,
    );
    unawaited(
      widget.run(() async {
        try {
          await _showPlaybackFlyout<void>(
            placement: FlyoutPlacementMode.bottomLeft,
            position: layout.position,
            builder: (_) => _playbackLibraryDynamicFlyout(
              section: section,
              panel: widget.buildLibraryPanel(section),
              box: box,
              above: layout.above,
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
    var menuConstraints =
        constraints ??
        _playbackMenuConstraints(
          navigatorBox,
          maxHeight:
              (navigatorBox.size.height -
                      2 * _PlaybackVideoControlsState._playbackMenuMargin)
                  .clamp(0.0, double.infinity),
        );
    unawaited(
      widget.run(() async {
        try {
          await _showPlaybackFlyout<void>(
            position: position,
            placement: placement,
            // FlyoutContent.useAcrylic only changes tint opacity in fluent_ui
            // 4.16.1. DisableAcrylic removes the actual video backdrop filter
            // and MenuFlyout carries it into every submenu's overlay entry.
            builder: (_) => DisableAcrylic(
              child: RepaintBoundary(
                child: MenuFlyout(
                  items: items(),
                  constraints: menuConstraints,
                  // Options sit flush vertically; the upscale group headings
                  // own the group gap through their own padding.
                  itemMargin: const EdgeInsetsDirectional.symmetric(
                    horizontal: 4,
                  ),
                ),
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
          showBehavior: SubItemShowAction.press,
          leading: const Icon(material.Icons.playlist_play_rounded, size: 16),
          items: (_) => [
            MenuFlyoutItem(
              text: const Text('后退 5 秒'),
              trailing: const _PlaybackMenuShortcut('←'),
              onPressed: () => _execute(_PlaybackCommand.back5),
            ),
            MenuFlyoutItem(
              text: const Text('前进 5 秒'),
              trailing: const _PlaybackMenuShortcut('→'),
              onPressed: () => _execute(_PlaybackCommand.forward5),
            ),
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
        MenuFlyoutItem(
          text: const Text('静音'),
          leading: Icon(
            player.state.volume == 0
                ? material.Icons.volume_off_rounded
                : material.Icons.volume_up_rounded,
            size: 16,
          ),
          trailing: const _PlaybackMenuShortcut('M'),
          selected: player.state.volume == 0,
          onPressed: () => _execute(_PlaybackCommand.mute),
        ),
        const MenuFlyoutSeparator(),
        MenuFlyoutSubItem(
          text: const Text('播放设置'),
          showBehavior: SubItemShowAction.press,
          leading: const Icon(material.Icons.settings_outlined, size: 16),
          items: (_) => _settingsItems(includeUpscale: false),
        ),
        MenuFlyoutItem(
          text: const Text('截屏并复制到剪贴板'),
          leading: const Icon(material.Icons.photo_camera_outlined, size: 16),
          trailing: const _PlaybackMenuShortcut('S'),
          onPressed: () => _execute(_PlaybackCommand.screenshot),
        ),
        const MenuFlyoutSeparator(),
        MenuFlyoutItem(
          text: const Text('视频信息'),
          leading: Icon(
            overlay.showInfo
                ? material.Icons.info_rounded
                : material.Icons.info_outline_rounded,
            size: 16,
          ),
          trailing: const _PlaybackMenuShortcut('Tab'),
          selected: overlay.showInfo,
          onPressed: () => _execute(_PlaybackCommand.info),
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
}
