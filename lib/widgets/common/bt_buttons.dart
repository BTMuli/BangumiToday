// Flutter imports:
import 'package:flutter/services.dart';

// Package imports:
import 'package:fluent_ui/fluent_ui.dart';

// Project imports:
import '../../core/theme/bt_theme.dart';

mixin ButtonInteractionMixin<T extends StatefulWidget> on State<T> {
  bool _isHovered = false;
  bool _isPressed = false;
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  double get pressedScale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: BTTheme.animationDurationFast,
      vsync: this as TickerProvider,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: pressedScale,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void handleTapDown(TapDownDetails details) {
    _onTapPressed();
  }

  void handleTapUp(TapUpDetails details) {
    _onTapReleased();
  }

  void handleTapCancel() {
    _onTapReleased();
  }

  void handleMouseEnter(bool isEnabled) {
    if (isEnabled) {
      setState(() => _isHovered = true);
    }
  }

  void handleMouseExit(bool isEnabled) {
    if (isEnabled) {
      setState(() => _isHovered = false);
    }
  }

  void _onTapPressed() {
    setState(() => _isPressed = true);
    _controller.forward();
  }

  void _onTapReleased() {
    setState(() => _isPressed = false);
    _controller.reverse();
  }

  bool get isHovered => _isHovered;
  bool get isPressed => _isPressed;
  Animation<double> get scaleAnimation => _scaleAnimation;
}

enum BTButtonType { primary, secondary, subtle, danger }

class BTButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final BTButtonType type;
  final bool isCompact;
  final IconData? icon;
  final bool isLoading;
  final bool isFullWidth;

  const BTButton({
    super.key,
    required this.child,
    this.onPressed,
    this.type = BTButtonType.primary,
    this.isCompact = false,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = false,
  });

  @override
  State<BTButton> createState() => _BTButtonState();
}

class _BTButtonState extends State<BTButton>
    with ButtonInteractionMixin<BTButton>, SingleTickerProviderStateMixin {
  @override
  double get pressedScale => 0.97;

  (Color, Color, Color) _getButtonColors(BuildContext context) {
    var accentColor = FluentTheme.of(context).accentColor;
    var isDark = FluentTheme.of(context).brightness == Brightness.dark;

    switch (widget.type) {
      case BTButtonType.primary:
        return (accentColor, accentColor.lighter, accentColor.darker);
      case BTButtonType.secondary:
        return (
          BTColors.surfaceSecondary(context),
          isDark ? const Color(0xFF353535) : const Color(0xFFE5E5E5),
          isDark ? const Color(0xFF1A1A1A) : const Color(0xFFD0D0D0),
        );
      case BTButtonType.subtle:
        return (
          Colors.transparent,
          isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.03),
          Colors.transparent,
        );
      case BTButtonType.danger:
        return (
          BTColors.error,
          BTColors.errorLight(context),
          const Color(0xFFA02828),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    var (baseColor, hoverColor, pressedColor) = _getButtonColors(context);
    var isDark = FluentTheme.of(context).brightness == Brightness.dark;
    var isDisabled = widget.onPressed == null || widget.isLoading;

    Widget content = Row(
      mainAxisSize: widget.isFullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.isLoading)
          SizedBox(
            width: 16,
            height: 16,
            child: ProgressRing(
              strokeWidth: 2,
              activeColor: widget.type == BTButtonType.primary
                  ? Colors.white
                  : FluentTheme.of(context).accentColor,
            ),
          )
        else if (widget.icon != null) ...[
          Icon(
            widget.icon,
            size: widget.isCompact ? 14 : 16,
            color: widget.type == BTButtonType.primary
                ? Colors.white
                : BTColors.textPrimary(context),
          ),
          SizedBox(width: 8),
        ],
        if (!widget.isLoading)
          DefaultTextStyle(
            style: TextStyle(
              fontSize: widget.isCompact ? 13 : 14,
              fontWeight: FontWeight.w500,
              color: widget.type == BTButtonType.primary
                  ? Colors.white
                  : BTColors.textPrimary(context),
            ),
            child: widget.child,
          ),
      ],
    );

    return MouseRegion(
      onEnter: (_) => handleMouseEnter(!isDisabled),
      onExit: (_) => handleMouseExit(!isDisabled),
      cursor: isDisabled
          ? SystemMouseCursors.forbidden
          : SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: isDisabled ? null : handleTapDown,
        onTapUp: isDisabled ? null : handleTapUp,
        onTapCancel: isDisabled ? null : handleTapCancel,
        onTap: isDisabled ? null : widget.onPressed,
        child: AnimatedBuilder(
          animation: scaleAnimation,
          builder: (context, child) {
            return Transform.scale(scale: scaleAnimation.value, child: child);
          },
          child: AnimatedContainer(
            duration: BTTheme.animationDurationFast,
            padding: EdgeInsets.symmetric(
              horizontal: widget.isCompact ? 12 : 16,
              vertical: widget.isCompact ? 6 : 10,
            ),
            decoration: BoxDecoration(
              color: isDisabled
                  ? baseColor.withValues(alpha: 0.5)
                  : (isPressed
                        ? pressedColor
                        : (isHovered ? hoverColor : baseColor)),
              borderRadius: BTRadius.mediumBR,
              border: widget.type == BTButtonType.secondary
                  ? Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.1)
                          : Colors.black.withValues(alpha: 0.06),
                    )
                  : null,
              boxShadow:
                  widget.type == BTButtonType.primary &&
                      isHovered &&
                      !isDisabled
                  ? [
                      BoxShadow(
                        color: FluentTheme.of(
                          context,
                        ).accentColor.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: content,
          ),
        ),
      ),
    );
  }
}

class BTIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final double? size;
  final Color? color;
  final bool isActive;

  const BTIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.tooltip,
    this.size,
    this.color,
    this.isActive = false,
  });

  @override
  State<BTIconButton> createState() => _BTIconButtonState();
}

class _BTIconButtonState extends State<BTIconButton>
    with ButtonInteractionMixin<BTIconButton>, SingleTickerProviderStateMixin {
  @override
  double get pressedScale => 0.92;

  @override
  Widget build(BuildContext context) {
    var accentColor = FluentTheme.of(context).accentColor;
    var iconColor =
        widget.color ??
        (widget.isActive ? accentColor : BTColors.textSecondary(context));
    var iconSize = widget.size ?? 18;

    Widget iconWidget = AnimatedContainer(
      duration: BTTheme.animationDurationFast,
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isHovered
            ? accentColor.withValues(alpha: 0.1)
            : (widget.isActive
                  ? accentColor.withValues(alpha: 0.08)
                  : Colors.transparent),
        borderRadius: BTRadius.smallBR,
      ),
      child: Icon(widget.icon, size: iconSize, color: iconColor),
    );

    if (isPressed) {
      iconWidget = ScaleTransition(scale: scaleAnimation, child: iconWidget);
    }

    if (widget.tooltip != null) {
      iconWidget = Tooltip(message: widget.tooltip!, child: iconWidget);
    }

    return MouseRegion(
      onEnter: (_) => handleMouseEnter(widget.onPressed != null),
      onExit: (_) => handleMouseExit(widget.onPressed != null),
      cursor: widget.onPressed != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.forbidden,
      child: GestureDetector(
        onTapDown: widget.onPressed != null ? handleTapDown : null,
        onTapUp: widget.onPressed != null ? handleTapUp : null,
        onTapCancel: widget.onPressed != null ? handleTapCancel : null,
        onTap: widget.onPressed,
        child: iconWidget,
      ),
    );
  }
}

class BTSegmentedControl extends StatefulWidget {
  final int selectedIndex;
  final List<String> options;
  final ValueChanged<int>? onChanged;

  const BTSegmentedControl({
    super.key,
    required this.selectedIndex,
    required this.options,
    this.onChanged,
  });

  @override
  State<BTSegmentedControl> createState() => _BTSegmentedControlState();
}

class _BTSegmentedControlState extends State<BTSegmentedControl> {
  late final List<FocusNode> _nodes = List.generate(
    widget.options.length,
    (_) => FocusNode(),
  );

  @override
  void dispose() {
    for (var node in _nodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _select(int index) {
    widget.onChanged?.call(index);
    _nodes[index].requestFocus();
  }

  void _move(int from, int delta) {
    var next = (from + delta + _nodes.length) % _nodes.length;
    _select(next);
  }

  @override
  Widget build(BuildContext context) {
    var isDark = FluentTheme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: BTColors.surfaceSecondary(context),
        borderRadius: BTRadius.mediumBR,
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.04),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < widget.options.length; i++)
            _SegmentedOption(
              label: widget.options[i],
              selected: i == widget.selectedIndex,
              focusNode: _nodes[i],
              onTap: () => _select(i),
              onMove: (delta) => _move(i, delta),
            ),
        ],
      ),
    );
  }
}

class _SegmentedOption extends StatefulWidget {
  const _SegmentedOption({
    required this.label,
    required this.selected,
    required this.focusNode,
    required this.onTap,
    required this.onMove,
  });

  final String label;
  final bool selected;
  final FocusNode focusNode;
  final VoidCallback onTap;
  final ValueChanged<int> onMove;

  @override
  State<_SegmentedOption> createState() => _SegmentedOptionState();
}

class _SegmentedOptionState extends State<_SegmentedOption> {
  var _hovered = false;
  var _focused = false;

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    var key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowLeft) {
      widget.onMove(-1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      widget.onMove(1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.space) {
      widget.onTap();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    var accentColor = FluentTheme.of(context).accentColor;
    var isSelected = widget.selected;
    return Focus(
      focusNode: widget.focusNode,
      onFocusChange: (value) => setState(() => _focused = value),
      onKeyEvent: _onKey,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: BTTheme.animationDurationFast,
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? accentColor
                  : (_hovered || _focused
                        ? accentColor.withValues(alpha: 0.08)
                        : Colors.transparent),
              borderRadius: BTRadius.smallBR,
              border: Border.all(
                color: _focused
                    ? accentColor.withValues(alpha: 0.6)
                    : Colors.transparent,
              ),
            ),
            child: Text(
              widget.label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected
                    ? Colors.white
                    : BTColors.textSecondary(context),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class BTToggleButton extends StatefulWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  final Widget child;
  final IconData? icon;

  const BTToggleButton({
    super.key,
    required this.value,
    this.onChanged,
    required this.child,
    this.icon,
  });

  @override
  State<BTToggleButton> createState() => _BTToggleButtonState();
}

class _BTToggleButtonState extends State<BTToggleButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    var accentColor = FluentTheme.of(context).accentColor;
    var isDark = FluentTheme.of(context).brightness == Brightness.dark;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onChanged != null
            ? () => widget.onChanged!(!widget.value)
            : null,
        child: AnimatedContainer(
          duration: BTTheme.animationDurationFast,
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: widget.value
                ? accentColor
                : (_isHovered
                      ? (isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.black.withValues(alpha: 0.03))
                      : Colors.transparent),
            borderRadius: BTRadius.mediumBR,
            border: Border.all(
              color: widget.value
                  ? accentColor
                  : (isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.06)),
            ),
            boxShadow: widget.value
                ? [
                    BoxShadow(
                      color: accentColor.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                Icon(
                  widget.icon,
                  size: 16,
                  color: widget.value
                      ? Colors.white
                      : BTColors.textSecondary(context),
                ),
                SizedBox(width: 8),
              ],
              DefaultTextStyle(
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: widget.value
                      ? Colors.white
                      : BTColors.textPrimary(context),
                ),
                child: widget.child,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class BTFloatingActionButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final bool isExtended;
  final String? label;

  const BTFloatingActionButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.tooltip,
    this.isExtended = false,
    this.label,
  });

  @override
  State<BTFloatingActionButton> createState() => _BTFloatingActionButtonState();
}

class _BTFloatingActionButtonState extends State<BTFloatingActionButton>
    with
        ButtonInteractionMixin<BTFloatingActionButton>,
        SingleTickerProviderStateMixin {
  @override
  double get pressedScale => 0.95;

  @override
  Widget build(BuildContext context) {
    var accentColor = FluentTheme.of(context).accentColor;

    Widget content = widget.isExtended && widget.label != null
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 20, color: Colors.white),
              SizedBox(width: 8),
              Text(
                widget.label!,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          )
        : Icon(widget.icon, size: 22, color: Colors.white);

    Widget fab = AnimatedBuilder(
      animation: scaleAnimation,
      builder: (context, child) {
        return Transform.scale(scale: scaleAnimation.value, child: child);
      },
      child: AnimatedContainer(
        duration: BTTheme.animationDurationFast,
        padding: EdgeInsets.all(widget.isExtended ? 16 : 14),
        decoration: BoxDecoration(
          color: accentColor,
          borderRadius: widget.isExtended ? BTRadius.largeBR : BTRadius.roundBR,
          boxShadow: [
            BoxShadow(
              color: accentColor.withValues(alpha: 0.4),
              blurRadius: isHovered ? 16 : 12,
              offset: Offset(0, isHovered ? 6 : 4),
            ),
          ],
        ),
        child: content,
      ),
    );

    if (widget.tooltip != null) {
      fab = Tooltip(message: widget.tooltip!, child: fab);
    }

    return MouseRegion(
      onEnter: (_) => handleMouseEnter(true),
      onExit: (_) => handleMouseExit(true),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: widget.onPressed != null ? handleTapDown : null,
        onTapUp: widget.onPressed != null ? handleTapUp : null,
        onTapCancel: widget.onPressed != null ? handleTapCancel : null,
        onTap: widget.onPressed,
        child: fab,
      ),
    );
  }
}
