import 'dart:ui';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../core/theme/bt_theme.dart';
import '../models/app/response.dart';
import '../widgets/app/app_resp_err.dart';

Future<String?> showInput(
  BuildContext context, {
  required String title,
  required String content,
  String value = '',
}) async {
  var controller = TextEditingController();
  if (value.isNotEmpty) controller.text = value;
  return await showDialog(
    barrierDismissible: true,
    context: context,
    builder: (_) => _BTContentDialog(
      title: title,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            content,
            style: BTTypography.body(context),
          ),
          SizedBox(height: 16.h),
          TextBox(
            controller: controller,
            autofocus: true,
            unfocusedColor: BTColors.divider(context),
          ),
        ],
      ),
      actions: [
        _BTDialogAction(
          text: '取消',
          onPressed: () => Navigator.of(context).pop(null),
          isPrimary: false,
        ),
        _BTDialogAction(
          text: '提交',
          onPressed: () => Navigator.of(context).pop(controller.text),
          isPrimary: true,
        ),
      ],
    ),
  );
}

Future<bool> showConfirm(
  BuildContext context, {
  required String title,
  required String content,
}) async {
  var confirm = await showDialog(
    barrierDismissible: true,
    context: context,
    builder: (_) => _BTContentDialog(
      title: title,
      content: Text(
        content,
        style: BTTypography.body(context),
      ),
      actions: [
        _BTDialogAction(
          text: '取消',
          onPressed: () => Navigator.of(context).pop(false),
          isPrimary: false,
        ),
        _BTDialogAction(
          text: '确定',
          onPressed: () => Navigator.of(context).pop(true),
          isPrimary: true,
        ),
      ],
    ),
  );
  if (confirm == null || confirm is! bool) return false;
  return confirm;
}

Future<void> showRespErr(
  BTResponse resp,
  BuildContext context, {
  String? title,
}) async {
  await showDialog(
    barrierDismissible: true,
    context: context,
    builder: (_) => _BTContentDialog(
      title: title ?? (resp.code == 0 ? '请求成功' : '请求失败'),
      content: AppRespErrWidget(resp),
      icon: resp.code == 0 ? FluentIcons.check_mark : FluentIcons.error_badge,
      iconColor: resp.code == 0 ? BTColors.success : BTColors.error,
      actions: [
        _BTDialogAction(
          text: '确定',
          onPressed: () => Navigator.of(context).pop(),
          isPrimary: true,
        ),
      ],
    ),
  );
}

class _BTContentDialog extends StatefulWidget {
  final String title;
  final Widget content;
  final List<Widget> actions;
  final IconData? icon;
  final Color? iconColor;

  const _BTContentDialog({
    required this.title,
    required this.content,
    required this.actions,
    this.icon,
    this.iconColor,
  });

  @override
  State<_BTContentDialog> createState() => _BTContentDialogState();
}

class _BTContentDialogState extends State<_BTContentDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var isDark = FluentTheme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return ScaleTransition(
          scale: _scaleAnimation,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: child,
          ),
        );
      },
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Center(
          child: Container(
            constraints: BoxConstraints(
              maxWidth: 450.w,
              minWidth: 300.w,
            ),
            margin: EdgeInsets.symmetric(horizontal: 24.w),
            decoration: BoxDecoration(
              color: BTColors.surfacePrimary(context).withValues(alpha: 0.95),
              borderRadius: BTRadius.largeBR,
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.05),
              ),
              boxShadow: BTTheme.shadow(context, level: BTShadowLevel.strong),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(20.w, 20.w, 20.w, 0),
                  child: Row(
                    children: [
                      if (widget.icon != null) ...[
                        Container(
                          padding: EdgeInsets.all(8.w),
                          decoration: BoxDecoration(
                            color: (widget.iconColor ?? FluentTheme.of(context).accentColor)
                                .withValues(alpha: 0.1),
                            borderRadius: BTRadius.smallBR,
                          ),
                          child: Icon(
                            widget.icon,
                            size: 20.sp,
                            color: widget.iconColor ?? FluentTheme.of(context).accentColor,
                          ),
                        ),
                        SizedBox(width: 12.w),
                      ],
                      Expanded(
                        child: Text(
                          widget.title,
                          style: BTTypography.subtitle(context).copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(20.w),
                  child: widget.content,
                ),
                Container(
                  padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 20.w),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: widget.actions
                        .asMap()
                        .entries
                        .map((entry) => Padding(
                              padding: EdgeInsets.only(
                                left: entry.key > 0 ? 8.w : 0,
                              ),
                              child: entry.value,
                            ))
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BTDialogAction extends StatefulWidget {
  final String text;
  final VoidCallback onPressed;
  final bool isPrimary;

  const _BTDialogAction({
    required this.text,
    required this.onPressed,
    required this.isPrimary,
  });

  @override
  State<_BTDialogAction> createState() => _BTDialogActionState();
}

class _BTDialogActionState extends State<_BTDialogAction>
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
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    _controller.forward();
  }

  void _onTapUp(TapUpDetails details) {
    _controller.reverse();
  }

  void _onTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    var accentColor = FluentTheme.of(context).accentColor;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        onTap: widget.onPressed,
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
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: widget.isPrimary
                  ? (_isHovered ? accentColor : accentColor.withValues(alpha: 0.9))
                  : (_isHovered
                      ? BTColors.surfaceSecondary(context)
                      : Colors.transparent),
              borderRadius: BTRadius.smallBR,
              border: widget.isPrimary
                  ? null
                  : Border.all(
                      color: BTColors.divider(context),
                    ),
              boxShadow: widget.isPrimary && _isHovered
                  ? [
                      BoxShadow(
                        color: accentColor.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Text(
              widget.text,
              style: TextStyle(
                color: widget.isPrimary ? Colors.white : BTColors.textPrimary(context),
                fontSize: 14.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class BTProgressDialog {
  static Future<void> show(
    BuildContext context, {
    required String title,
    String? message,
    double? progress,
  }) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _BTProgressDialogContent(
        title: title,
        message: message,
        progress: progress,
      ),
    );
  }
}

class _BTProgressDialogContent extends StatelessWidget {
  final String title;
  final String? message;
  final double? progress;

  const _BTProgressDialogContent({
    required this.title,
    this.message,
    this.progress,
  });

  @override
  Widget build(BuildContext context) {
    var isDark = FluentTheme.of(context).brightness == Brightness.dark;

    return Center(
      child: Container(
        constraints: BoxConstraints(maxWidth: 320.w),
        margin: EdgeInsets.symmetric(horizontal: 24.w),
        padding: EdgeInsets.all(20.w),
        decoration: BoxDecoration(
          color: BTColors.surfacePrimary(context).withValues(alpha: 0.95),
          borderRadius: BTRadius.largeBR,
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.05),
          ),
          boxShadow: BTTheme.shadow(context, level: BTShadowLevel.strong),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 24.w,
                  height: 24.w,
                  child: ProgressRing(
                    value: progress,
                    strokeWidth: 2,
                  ),
                ),
                SizedBox(width: 16.w),
                Expanded(
                  child: Text(
                    title,
                    style: BTTypography.subtitle(context),
                  ),
                ),
              ],
            ),
            if (message != null) ...[
              SizedBox(height: 12.h),
              Text(
                message!,
                style: BTTypography.caption(context),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
