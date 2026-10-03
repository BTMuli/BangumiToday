// Flutter imports:
import 'package:flutter/services.dart';

// Package imports:
import 'package:fluent_ui/fluent_ui.dart';

/// 动态导航条目的首字图标。
///
/// 用标题首字 + 稳定配色区分不同条目，紧凑模式下仍可辨认；
/// 右键弹出管理菜单（关闭当前 / 关闭其他 / 关闭全部）。
class NavItemIcon extends StatefulWidget {
  const NavItemIcon({
    super.key,
    required this.title,
    this.onClose,
    this.onCloseOthers,
    this.onCloseAll,
    this.size = 18,
  });

  final String title;
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
  void dispose() {
    _menuController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String get _firstChar {
    var trimmed = widget.title.trim();
    if (trimmed.isEmpty) return '#';
    return trimmed.characters.first;
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

  @override
  Widget build(BuildContext context) {
    var color = _palette[widget.title.hashCode.abs() % _palette.length];
    var glyph = _firstChar;
    return FlyoutTarget(
      controller: _menuController,
      child: Tooltip(
        message: widget.title,
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
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(4),
                border: _focused
                    ? Border.all(color: color.withValues(alpha: 0.7))
                    : null,
              ),
              child: Text(
                glyph,
                style: TextStyle(
                  color: color,
                  fontSize: widget.size * 0.62,
                  fontWeight: FontWeight.w600,
                  height: 1,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
