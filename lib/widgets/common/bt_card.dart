import 'dart:async';
import 'dart:ui';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../core/theme/bt_theme.dart';

class BTCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? backgroundColor;
  final double? borderRadius;
  final bool useAcrylic;
  final double acrylicOpacity;
  final bool useReveal;
  final bool useShadow;
  final BTShadowLevel shadowLevel;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Color? borderColor;
  final double? borderWidth;

  const BTCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.backgroundColor,
    this.borderRadius,
    this.useAcrylic = true,
    this.acrylicOpacity = 0.75,
    this.useReveal = true,
    this.useShadow = true,
    this.shadowLevel = BTShadowLevel.medium,
    this.onTap,
    this.onLongPress,
    this.borderColor,
    this.borderWidth,
  });

  @override
  State<BTCard> createState() => _BTCardState();
}

class _BTCardState extends State<BTCard> with SingleTickerProviderStateMixin {
  final GlobalKey _cardKey = GlobalKey();
  Offset _hoverPosition = Offset.zero;
  bool _isHovered = false;

  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: BTTheme.animationDurationFast,
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handleHover(PointerHoverEvent event) {
    if (!widget.useReveal) return;
    final RenderBox? renderBox =
        _cardKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    setState(() {
      _hoverPosition = event.localPosition;
      _isHovered = true;
    });
  }

  void _handleExit(PointerExitEvent event) {
    if (!widget.useReveal) return;
    setState(() {
      _isHovered = false;
    });
  }

  void _handleTapDown(TapDownDetails details) {
    if (widget.onTap == null) return;
    _animationController.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    if (widget.onTap == null) return;
    _animationController.reverse();
  }

  void _handleTapCancel() {
    if (widget.onTap == null) return;
    _animationController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = FluentTheme.of(context).brightness == Brightness.dark;
    final borderRadius = widget.borderRadius ?? BTRadius.large;
    final effectivePadding = widget.padding ?? EdgeInsets.all(12.w);

    Widget cardContent = Container(
      key: _cardKey,
      padding: effectivePadding,
      decoration: BoxDecoration(
        color:
            widget.backgroundColor ??
            (widget.useAcrylic
                ? BTAcrylic.backgroundColor(
                    context,
                    opacity: widget.acrylicOpacity,
                  )
                : BTColors.surfacePrimary(context)),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color:
              widget.borderColor ??
              (isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.05)),
          width: widget.borderWidth ?? 1,
        ),
        boxShadow: widget.useShadow
            ? BTTheme.shadow(context, level: widget.shadowLevel)
            : null,
      ),
      child: widget.child,
    );

    if (widget.useAcrylic) {
      cardContent = ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: BTAcrylic.cardBlurAmount,
            sigmaY: BTAcrylic.cardBlurAmount,
          ),
          child: cardContent,
        ),
      );
    }

    if (widget.useReveal) {
      cardContent = Stack(
        children: [
          cardContent,
          if (_isHovered)
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(borderRadius),
                child: CustomPaint(
                  painter: _RevealPainter(
                    position: _hoverPosition,
                    isDark: isDark,
                  ),
                ),
              ),
            ),
        ],
      );
    }

    if (widget.onTap != null || widget.onLongPress != null) {
      cardContent = MouseRegion(
        onHover: _handleHover,
        onExit: _handleExit,
        cursor: widget.onTap != null
            ? SystemMouseCursors.click
            : MouseCursor.defer,
        child: GestureDetector(
          onTapDown: widget.onTap != null ? _handleTapDown : null,
          onTapUp: widget.onTap != null ? _handleTapUp : null,
          onTapCancel: widget.onTap != null ? _handleTapCancel : null,
          onTap: widget.onTap,
          onLongPress: widget.onLongPress,
          child: AnimatedBuilder(
            animation: _scaleAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnimation.value,
                child: child,
              );
            },
            child: cardContent,
          ),
        ),
      );
    }

    if (widget.margin != null) {
      cardContent = Padding(padding: widget.margin!, child: cardContent);
    }

    return AnimatedContainer(
      duration: BTTheme.animationDurationNormal,
      curve: BTTheme.animationCurve,
      child: cardContent,
    );
  }
}

class _RevealPainter extends CustomPainter {
  final Offset position;
  final bool isDark;

  _RevealPainter({required this.position, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    if (position.dx < 0 || position.dy < 0) return;

    final gradient = RadialGradient(
      center: Alignment(
        (position.dx / size.width) * 2 - 1,
        (position.dy / size.height) * 2 - 1,
      ),
      radius: 0.8,
      colors: [
        (isDark ? Colors.white : FluentThemeData.light().accentColor)
            .withValues(alpha: 0.08),
        Colors.transparent,
      ],
      stops: const [0.0, 1.0],
    );

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..blendMode = BlendMode.srcOver;

    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant _RevealPainter oldDelegate) {
    return oldDelegate.position != position || oldDelegate.isDark != isDark;
  }
}

class BTHoverCard extends StatefulWidget {
  final Widget child;
  final Widget Function(BuildContext context) hoverBuilder;
  final Duration hoverDelay;
  final EdgeInsetsGeometry? padding;
  final double? borderRadius;

  const BTHoverCard({
    super.key,
    required this.child,
    required this.hoverBuilder,
    this.hoverDelay = const Duration(milliseconds: 300),
    this.padding,
    this.borderRadius,
  });

  @override
  State<BTHoverCard> createState() => _BTHoverCardState();
}

class _BTHoverCardState extends State<BTHoverCard> {
  final FlyoutController _controller = FlyoutController();
  Timer? _hoverTimer;

  @override
  void dispose() {
    _controller.dispose();
    _hoverTimer?.cancel();
    super.dispose();
  }

  void _showFlyout() {
    _hoverTimer = Timer(widget.hoverDelay, () {
      _controller.showFlyout(
        barrierDismissible: true,
        dismissOnPointerMoveAway: true,
        builder: widget.hoverBuilder,
      );
    });
  }

  void _cancelFlyout() {
    _hoverTimer?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _showFlyout(),
      onExit: (_) => _cancelFlyout(),
      child: FlyoutTarget(controller: _controller, child: widget.child),
    );
  }
}

class BTShimmer extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Color? baseColor;
  final Color? highlightColor;

  const BTShimmer({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 1500),
    this.baseColor,
    this.highlightColor,
  });

  @override
  State<BTShimmer> createState() => _BTShimmerState();
}

class _BTShimmerState extends State<BTShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this)
      ..repeat();
    _animation = Tween<double>(begin: -2, end: 2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = FluentTheme.of(context).brightness == Brightness.dark;
    final baseColor =
        widget.baseColor ??
        (isDark ? const Color(0xFF424242) : const Color(0xFFEEEEEE));
    final highlightColor =
        widget.highlightColor ??
        (isDark ? const Color(0xFF616161) : const Color(0xFFF5F5F5));

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [baseColor, highlightColor, baseColor],
              stops: const [0.0, 0.5, 1.0],
              transform: _SlideGradientTransform(_animation.value),
            ).createShader(bounds);
          },
          child: widget.child,
        );
      },
    );
  }
}

class _SlideGradientTransform extends GradientTransform {
  final double slidePercent;

  const _SlideGradientTransform(this.slidePercent);

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * slidePercent, 0.0, 0.0);
  }
}
