import 'dart:ui';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class FluentRssCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onSecondaryTap;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;

  const FluentRssCard({
    super.key,
    required this.child,
    this.onTap,
    this.onSecondaryTap,
    this.width,
    this.height,
    this.padding,
  });

  @override
  State<FluentRssCard> createState() => _FluentRssCardState();
}

class _FluentRssCardState extends State<FluentRssCard> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    var theme = FluentTheme.of(context);
    var backgroundColor = theme.brightness == Brightness.light
        ? Colors.white.withValues(alpha: _isHovered ? 0.95 : 0.85)
        : Colors.grey[190].withValues(alpha: _isHovered ? 0.95 : 0.85);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.onTap,
        onSecondaryTap: widget.onSecondaryTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(8.r),
            border: Border.all(
              color: theme.brightness == Brightness.light
                  ? Colors.grey[60]
                  : Colors.grey[130],
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: _isHovered ? 0.12 : 0.08),
                blurRadius: _isHovered ? 12 : 8,
                spreadRadius: 0,
                offset: Offset(0, _isHovered ? 4 : 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(7.r),
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: _isHovered ? 20 : 10,
                sigmaY: _isHovered ? 20 : 10,
              ),
              child: Transform.translate(
                offset: Offset(0, _isPressed ? 2.0 : 0.0),
                child: Padding(
                  padding: widget.padding ?? EdgeInsets.all(12.r),
                  child: widget.child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
