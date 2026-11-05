// Flutter imports:
import 'package:flutter/services.dart';

// Package imports:
import 'package:cached_network_image/cached_network_image.dart';
import 'package:fluent_ui/fluent_ui.dart';

// Project imports:
import '../../core/cache/subject_cache.dart';
import '../bangumi/bt_bangumi_cover.dart';

/// 动态导航条目图标：优先显示缓存封面缩略图，否则用标题首字 + 稳定配色。
///
/// 右键弹出管理菜单（关闭当前 / 关闭其他 / 关闭全部）。
class NavItemIcon extends StatefulWidget {
  const NavItemIcon({
    super.key,
    required this.title,
    this.subjectId,
    this.onClose,
    this.onCloseOthers,
    this.onCloseAll,
    this.size = 18,
  });

  final String title;
  final int? subjectId;
  final VoidCallback? onClose;
  final VoidCallback? onCloseOthers;
  final VoidCallback? onCloseAll;
  final double size;

  @override
  State<NavItemIcon> createState() => _NavItemIconState();
}

class _NavItemIconState extends State<NavItemIcon> {
  final FlyoutController _menuController = FlyoutController();
  final FocusNode _focusNode = FocusNode();
  var _focused = false;
  String? _coverUrl;

  static const _palette = <Color>[
    Color(0xFF0F6CBD),
    Color(0xFF8764B8),
    Color(0xFFCA5010),
    Color(0xFF0E8A72),
    Color(0xFFB146C2),
    Color(0xFFC239B3),
    Color(0xFF00B7C3),
    Color(0xFF498205),
    Color(0xFFD13438),
    Color(0xFF986F0B),
  ];

  @override
  void initState() {
    super.initState();
    _loadCover();
  }

  @override
  void didUpdateWidget(covariant NavItemIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.subjectId != widget.subjectId) {
      _coverUrl = null;
      _loadCover();
    }
  }

  @override
  void dispose() {
    _menuController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadCover() async {
    var id = widget.subjectId;
    if (id == null || id <= 0) return;
    var subject = await BgmSubjectCache().read(id, allowStale: true);
    if (!mounted || widget.subjectId != id) return;
    var url = subject?.images.grid;
    if (url == null || url.isEmpty) url = subject?.images.small;
    if (url == null || url.isEmpty) return;
    setState(() => _coverUrl = url);
  }

  String get _firstChar {
    var trimmed = widget.title.trim();
    if (trimmed.isEmpty) return '#';
    return trimmed.characters.first;
  }

  String get _tooltip {
    var id = widget.subjectId;
    if (id == null || id <= 0) return widget.title;
    return '${widget.title} #$id';
  }

  void _openMenu() {
    _menuController.showFlyout(
      barrierDismissible: true,
      dismissOnPointerMoveAway: false,
      dismissWithEsc: true,
      builder: (context) => MenuFlyout(
        items: [
          if (widget.onClose != null)
            MenuFlyoutItem(
              leading: Icon(FluentIcons.clear, size: 14),
              text: Text(
                '关闭「${widget.title}」',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onPressed: widget.onClose,
            ),
          if (widget.onCloseOthers != null)
            MenuFlyoutItem(
              leading: Icon(FluentIcons.cancel, size: 14),
              text: const Text('关闭其他'),
              onPressed: widget.onCloseOthers,
            ),
          if (widget.onCloseAll != null)
            MenuFlyoutItem(
              leading: Icon(FluentIcons.delete, size: 14),
              text: const Text('关闭全部'),
              onPressed: widget.onCloseAll,
            ),
        ],
      ),
    );
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    var key = event.logicalKey;
    var isContextMenu =
        key == LogicalKeyboardKey.contextMenu ||
        (key == LogicalKeyboardKey.f10 &&
            HardwareKeyboard.instance.isShiftPressed);
    if (isContextMenu) {
      _openMenu();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Widget _buildGlyph(Color color) {
    return Text(
      _firstChar,
      style: TextStyle(
        color: color,
        fontSize: widget.size * 0.62,
        fontWeight: FontWeight.w600,
        height: 1,
      ),
    );
  }

  Widget _buildFace(Color color) {
    var cover = _coverUrl;
    if (cover == null || cover.isEmpty) return _buildGlyph(color);
    var dpr = MediaQuery.devicePixelRatioOf(context);
    var cache = BangumiCoverUrl.memCacheSize(
      logicalWidth: widget.size,
      logicalHeight: widget.size,
      devicePixelRatio: dpr,
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: CachedNetworkImage(
        imageUrl: BangumiCoverUrl.resolve(
          cover,
          maxEdge: BangumiCoverUrl.thumbMaxEdge,
        ),
        width: widget.size,
        height: widget.size,
        fit: BoxFit.cover,
        memCacheWidth: cache.width,
        memCacheHeight: cache.height,
        fadeInDuration: Duration.zero,
        fadeOutDuration: Duration.zero,
        placeholder: (context, url) => _buildGlyph(color),
        errorWidget: (context, url, error) => _buildGlyph(color),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    var color = _palette[widget.title.hashCode.abs() % _palette.length];
    return Tooltip(
      message: _tooltip,
      child: FlyoutTarget(
        controller: _menuController,
        child: Focus(
          focusNode: _focusNode,
          onFocusChange: (value) => setState(() => _focused = value),
          onKeyEvent: _onKey,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onSecondaryTap: _openMenu,
            child: Container(
              width: widget.size,
              height: widget.size,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _coverUrl == null
                    ? color.withValues(alpha: 0.14)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(4),
                border: _focused
                    ? Border.all(color: color.withValues(alpha: 0.7))
                    : null,
              ),
              child: _buildFace(color),
            ),
          ),
        ),
      ),
    );
  }
}
