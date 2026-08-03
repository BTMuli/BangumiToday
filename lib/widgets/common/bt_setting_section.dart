import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../core/theme/bt_theme.dart';
import 'bt_card.dart';

/// 设置页分区卡片
///
/// 统一设置页各分区的视觉样式：圆角卡片 + 强调色图标 + 可折叠内容。
class BTSettingSection extends StatefulWidget {
  /// 分区图标
  final IconData icon;

  /// 分区标题
  final String title;

  /// 分区副标题
  final String? subtitle;

  /// 标题右侧额外控件
  final Widget? trailing;

  /// 是否默认展开
  final bool initiallyExpanded;

  /// 分区内容
  final List<Widget> children;

  /// 构造函数
  const BTSettingSection({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.initiallyExpanded = true,
    this.children = const [],
  });

  @override
  State<BTSettingSection> createState() => _BTSettingSectionState();
}

class _BTSettingSectionState extends State<BTSettingSection> {
  late bool _expanded = widget.initiallyExpanded;
  bool _hovered = false;

  void _toggle() {
    setState(() => _expanded = !_expanded);
  }

  @override
  Widget build(BuildContext context) {
    var accent = FluentTheme.of(context).accentColor;
    var isDark = FluentTheme.of(context).brightness == Brightness.dark;

    return BTCard(
      useAcrylic: true,
      // 深色模式下用略亮的深灰半透明底，避免卡片背景纯黑且与页面保持区分
      backgroundColor: isDark
          ? const Color(0xFF3C3C3C).withValues(alpha: 0.8)
          : null,
      useShadow: true,
      shadowLevel: BTShadowLevel.subtle,
      padding: EdgeInsets.zero,
      borderRadius: BTRadius.large,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          MouseRegion(
            cursor: SystemMouseCursors.click,
            onEnter: (_) => setState(() => _hovered = true),
            onExit: (_) => setState(() => _hovered = false),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _toggle,
              child: AnimatedContainer(
                duration: BTTheme.animationDurationFast,
                curve: BTTheme.animationCurve,
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
                decoration: BoxDecoration(
                  color: _hovered
                      ? accent.withValues(alpha: 0.05)
                      : Colors.transparent,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(BTRadius.large),
                  ),
                ),
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: BTTheme.animationDurationFast,
                      curve: BTTheme.animationCurve,
                      width: 38.w,
                      height: 38.w,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            _hovered ? accent.lighter : accent,
                            accent.darker,
                          ],
                        ),
                        borderRadius: BTRadius.mediumBR,
                        boxShadow: [
                          BoxShadow(
                            color: accent.withValues(alpha: 0.25),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        widget.icon,
                        size: 19.sp,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            style: BTTypography.bodyStrong(
                              context,
                            ).copyWith(fontSize: 15.sp),
                          ),
                          if (widget.subtitle != null) ...[
                            SizedBox(height: 2.h),
                            Text(
                              widget.subtitle!,
                              style: BTTypography.caption(context),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (widget.trailing != null) ...[
                      widget.trailing!,
                      SizedBox(width: 8.w),
                    ],
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: BTTheme.animationDurationFast,
                      curve: BTTheme.animationCurve,
                      child: Icon(
                        FluentIcons.chevron_down,
                        size: 16.sp,
                        color: _hovered
                            ? accent
                            : BTColors.textSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          ClipRect(
            child: AnimatedSize(
              duration: BTTheme.animationDurationNormal,
              curve: BTTheme.animationCurve,
              alignment: Alignment.topCenter,
              child: _expanded
                  ? Container(
                      padding: EdgeInsets.fromLTRB(16.w, 6.h, 16.w, 16.h),
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(color: BTColors.divider(context)),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: widget.children,
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ),
        ],
      ),
    );
  }
}

/// 设置项之间的分隔线
class BTSettingDivider extends StatelessWidget {
  /// 构造函数
  const BTSettingDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: Divider(
        style: DividerThemeData(
          thickness: 1,
          horizontalMargin: EdgeInsets.zero,
          decoration: BoxDecoration(color: BTColors.divider(context)),
        ),
      ),
    );
  }
}

/// 设置分组标题
class BTSettingGroupTitle extends StatelessWidget {
  /// 标题文本
  final String text;

  /// 构造函数
  const BTSettingGroupTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: 12.h, bottom: 6.h),
      child: Text(
        text,
        style: BTTypography.bodyStrong(
          context,
        ).copyWith(fontSize: 13.sp, color: FluentTheme.of(context).accentColor),
      ),
    );
  }
}

/// 设置页提示条
class BTSettingHint extends StatelessWidget {
  /// 提示图标
  final IconData icon;

  /// 提示文本
  final String message;

  /// 强调色，默认取主题强调色
  final Color? color;

  /// 构造函数
  const BTSettingHint({
    super.key,
    required this.icon,
    required this.message,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    var tint = color ?? FluentTheme.of(context).accentColor;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.08),
        borderRadius: BTRadius.mediumBR,
        border: Border.all(color: tint.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16.sp, color: tint),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 13.sp,
                height: 1.5,
                color: BTColors.textSecondary(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
