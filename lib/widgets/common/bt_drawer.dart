import 'dart:ui';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../core/theme/bt_theme.dart';

enum BTDrawerPosition { left, right }

class BTDrawerRoute<T> extends PopupRoute<T> {
  final Widget child;
  final BTDrawerPosition position;
  final double width;
  final Color? backgroundColor;

  BTDrawerRoute({
    required this.child,
    this.position = BTDrawerPosition.right,
    this.width = 400,
    this.backgroundColor,
    super.settings,
  });

  @override
  Color? get barrierColor => Colors.black.withValues(alpha: 0.3);

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => '关闭抽屉';

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    var isDark = FluentTheme.of(context).brightness == Brightness.dark;
    var isRight = position == BTDrawerPosition.right;

    return Align(
      alignment: isRight ? Alignment.centerRight : Alignment.centerLeft,
      child: SizeTransition(
        sizeFactor: CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        ),
        axis: isRight ? Axis.horizontal : Axis.horizontal,
        axisAlignment: isRight ? 1.0 : -1.0,
        child: Container(
          width: width.w,
          height: double.infinity,
          decoration: BoxDecoration(
            color: backgroundColor ?? BTColors.surfacePrimary(context),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.15),
                blurRadius: 20,
                offset: Offset(isRight ? -4 : 4, 0),
              ),
            ],
          ),
          child: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Duration get transitionDuration => const Duration(milliseconds: 250);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 200);
}

Future<T?> showBTDrawer<T>({
  required BuildContext context,
  required Widget child,
  BTDrawerPosition position = BTDrawerPosition.right,
  double width = 400,
  Color? backgroundColor,
}) {
  return Navigator.of(context).push<T>(
    BTDrawerRoute<T>(
      child: child,
      position: position,
      width: width,
      backgroundColor: backgroundColor,
    ),
  );
}

class BTDrawer extends StatelessWidget {
  final String title;
  final Widget child;
  final List<Widget>? actions;
  final VoidCallback? onClose;

  const BTDrawer({
    super.key,
    required this.title,
    required this.child,
    this.actions,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    var isDark = FluentTheme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.05),
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: BTTypography.subtitle(context).copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (actions != null) ...actions!,
              SizedBox(width: 8.w),
              Tooltip(
                message: '关闭',
                child: IconButton(
                  icon: Icon(
                    FluentIcons.cancel,
                    size: 16.sp,
                    color: BTColors.textSecondary(context),
                  ),
                  onPressed: onClose ?? () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}

class BTDrawerButton extends StatefulWidget {
  final String title;
  final Widget Function(BuildContext) builder;
  final IconData? icon;
  final BTDrawerPosition position;
  final double width;

  const BTDrawerButton({
    super.key,
    required this.title,
    required this.builder,
    this.icon,
    this.position = BTDrawerPosition.right,
    this.width = 400,
  });

  @override
  State<BTDrawerButton> createState() => _BTDrawerButtonState();
}

class _BTDrawerButtonState extends State<BTDrawerButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    var accentColor = FluentTheme.of(context).accentColor;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => showBTDrawer(
          context: context,
          position: widget.position,
          width: widget.width,
          child: BTDrawer(
            title: widget.title,
            child: widget.builder(context),
          ),
        ),
        child: AnimatedContainer(
          duration: BTTheme.animationDurationFast,
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
          decoration: BoxDecoration(
            color: _isHovered
                ? accentColor.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BTRadius.smallBR,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                Icon(
                  widget.icon,
                  size: 16.sp,
                  color: accentColor,
                ),
                SizedBox(width: 8.w),
              ],
              Text(
                widget.title,
                style: BTTypography.body(context).copyWith(
                  color: accentColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
