import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../core/theme/bt_theme.dart';

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
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  bool _isPressed = false;
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: BTTheme.animationDurationFast,
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (widget.onPressed == null || widget.isLoading) return;
    setState(() => _isPressed = true);
    _controller.forward();
  }

  void _onTapUp(TapUpDetails details) {
    setState(() => _isPressed = false);
    _controller.reverse();
  }

  void _onTapCancel() {
    setState(() => _isPressed = false);
    _controller.reverse();
  }

  (Color, Color, Color) _getButtonColors(BuildContext context) {
    final accentColor = FluentTheme.of(context).accentColor;
    final isDark = FluentTheme.of(context).brightness == Brightness.dark;

    switch (widget.type) {
      case BTButtonType.primary:
        return (
          accentColor,
          accentColor.lighter,
          accentColor.darker,
        );
      case BTButtonType.secondary:
        return (
          BTColors.surfaceSecondary(context),
          isDark ? const Color(0xFF353535) : const Color(0xFFE5E5E5),
          isDark ? const Color(0xFF1A1A1A) : const Color(0xFFD0D0D0),
        );
      case BTButtonType.subtle:
        return (
          Colors.transparent,
          isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
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
    final (baseColor, hoverColor, pressedColor) = _getButtonColors(context);
    final isDark = FluentTheme.of(context).brightness == Brightness.dark;
    final isDisabled = widget.onPressed == null || widget.isLoading;

    Widget content = Row(
      mainAxisSize: widget.isFullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.isLoading)
          SizedBox(
            width: 16.w,
            height: 16.w,
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
            size: (widget.isCompact ? 14 : 16).sp,
            color: widget.type == BTButtonType.primary
                ? Colors.white
                : BTColors.textPrimary(context),
          ),
          SizedBox(width: 8.w),
        ],
        if (!widget.isLoading)
          DefaultTextStyle(
            style: TextStyle(
              fontSize: (widget.isCompact ? 13 : 14).sp,
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
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: isDisabled ? SystemMouseCursors.forbidden : SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        onTap: isDisabled ? null : widget.onPressed,
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: child,
            );
          },
          child: AnimatedContainer(
            duration: BTTheme.animationDurationFast,
            padding: EdgeInsets.symmetric(
              horizontal: widget.isCompact ? 12.w : 16.w,
              vertical: widget.isCompact ? 6.h : 10.h,
            ),
            decoration: BoxDecoration(
              color: isDisabled
                  ? baseColor.withValues(alpha: 0.5)
                  : (_isPressed
                      ? pressedColor
                      : (_isHovered ? hoverColor : baseColor)),
              borderRadius: BTRadius.mediumBR,
              border: widget.type == BTButtonType.secondary
                  ? Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.1)
                          : Colors.black.withValues(alpha: 0.06),
                    )
                  : null,
              boxShadow: widget.type == BTButtonType.primary && _isHovered && !isDisabled
                  ? [
                      BoxShadow(
                        color: FluentTheme.of(context)
                            .accentColor
                            .withValues(alpha: 0.3),
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
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  bool _isPressed = false;
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: BTTheme.animationDurationFast,
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = FluentTheme.of(context).accentColor;
    final iconColor = widget.color ?? (widget.isActive ? accentColor : BTColors.textSecondary(context));
    final iconSize = widget.size ?? 18.sp;

    Widget iconWidget = AnimatedContainer(
      duration: BTTheme.animationDurationFast,
      padding: EdgeInsets.all(8.w),
      decoration: BoxDecoration(
        color: _isHovered
            ? accentColor.withValues(alpha: 0.1)
            : (widget.isActive ? accentColor.withValues(alpha: 0.08) : Colors.transparent),
        borderRadius: BTRadius.smallBR,
      ),
      child: Icon(
        widget.icon,
        size: iconSize,
        color: iconColor,
      ),
    );

    if (_isPressed) {
      iconWidget = ScaleTransition(
        scale: _scaleAnimation,
        child: iconWidget,
      );
    }

    if (widget.tooltip != null) {
      iconWidget = Tooltip(message: widget.tooltip!, child: iconWidget);
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: widget.onPressed != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.forbidden,
      child: GestureDetector(
        onTapDown: widget.onPressed != null
            ? (_) {
                setState(() => _isPressed = true);
                _controller.forward();
              }
            : null,
        onTapUp: widget.onPressed != null
            ? (_) {
                setState(() => _isPressed = false);
                _controller.reverse();
              }
            : null,
        onTapCancel: widget.onPressed != null
            ? () {
                setState(() => _isPressed = false);
                _controller.reverse();
              }
            : null,
        onTap: widget.onPressed,
        child: iconWidget,
      ),
    );
  }
}

class BTSegmentedControl extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final isDark = FluentTheme.of(context).brightness == Brightness.dark;
    final accentColor = FluentTheme.of(context).accentColor;

    return Container(
      padding: EdgeInsets.all(4.w),
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
        children: options.asMap().entries.map((entry) {
          final isSelected = entry.key == selectedIndex;
          return GestureDetector(
            onTap: onChanged != null ? () => onChanged!(entry.key) : null,
            child: AnimatedContainer(
              duration: BTTheme.animationDurationFast,
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: isSelected ? accentColor : Colors.transparent,
                borderRadius: BTRadius.smallBR,
              ),
              child: Text(
                entry.value,
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected
                      ? Colors.white
                      : BTColors.textSecondary(context),
                ),
              ),
            ),
          );
        }).toList(),
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
    final accentColor = FluentTheme.of(context).accentColor;
    final isDark = FluentTheme.of(context).brightness == Brightness.dark;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onChanged != null ? () => widget.onChanged!(!widget.value) : null,
        child: AnimatedContainer(
          duration: BTTheme.animationDurationFast,
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
          decoration: BoxDecoration(
            color: widget.value
                ? accentColor
                : (_isHovered
                    ? (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03))
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
                  size: 16.sp,
                  color: widget.value ? Colors.white : BTColors.textSecondary(context),
                ),
                SizedBox(width: 8.w),
              ],
              DefaultTextStyle(
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w500,
                  color: widget.value ? Colors.white : BTColors.textPrimary(context),
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
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: BTTheme.animationDurationFast,
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = FluentTheme.of(context).accentColor;

    Widget content = widget.isExtended && widget.label != null
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 20.sp, color: Colors.white),
              SizedBox(width: 8.w),
              Text(
                widget.label!,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          )
        : Icon(widget.icon, size: 22.sp, color: Colors.white);

    Widget fab = AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        );
      },
      child: AnimatedContainer(
        duration: BTTheme.animationDurationFast,
        padding: EdgeInsets.all(widget.isExtended ? 16.w : 14.w),
        decoration: BoxDecoration(
          color: accentColor,
          borderRadius: widget.isExtended ? BTRadius.largeBR : BTRadius.roundBR,
          boxShadow: [
            BoxShadow(
              color: accentColor.withValues(alpha: 0.4),
              blurRadius: _isHovered ? 16 : 12,
              offset: Offset(0, _isHovered ? 6 : 4),
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
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: widget.onPressed != null
            ? (_) {
                _controller.forward();
              }
            : null,
        onTapUp: widget.onPressed != null
            ? (_) {
                _controller.reverse();
              }
            : null,
        onTapCancel: widget.onPressed != null
            ? () {
                _controller.reverse();
              }
            : null,
        onTap: widget.onPressed,
        child: fab,
      ),
    );
  }
}
