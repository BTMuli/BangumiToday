import 'dart:ui';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class BTTheme {
  BTTheme._();

  static Duration get animationDurationFast =>
      const Duration(milliseconds: 150);

  static Duration get animationDurationNormal =>
      const Duration(milliseconds: 250);

  static Duration get animationDurationSlow =>
      const Duration(milliseconds: 350);

  static Curve get animationCurve => Curves.easeOutCubic;

  static Curve get animationCurveEnter => Curves.easeOutQuart;

  static Curve get animationCurveExit => Curves.easeInQuart;

  static List<BoxShadow> shadow(
    BuildContext context, {
    BTShadowLevel level = BTShadowLevel.medium,
  }) {
    var isDark = FluentTheme.of(context).brightness == Brightness.dark;
    var baseColor = isDark ? Colors.black : const Color(0xFF000000);

    switch (level) {
      case BTShadowLevel.none:
        return [];
      case BTShadowLevel.subtle:
        return [
          BoxShadow(
            color: baseColor.withValues(alpha: isDark ? 0.2 : 0.08),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ];
      case BTShadowLevel.medium:
        return [
          BoxShadow(
            color: baseColor.withValues(alpha: isDark ? 0.3 : 0.12),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
          BoxShadow(
            color: baseColor.withValues(alpha: isDark ? 0.15 : 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ];
      case BTShadowLevel.strong:
        return [
          BoxShadow(
            color: baseColor.withValues(alpha: isDark ? 0.4 : 0.16),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: baseColor.withValues(alpha: isDark ? 0.2 : 0.08),
            blurRadius: 32,
            offset: const Offset(0, 16),
          ),
        ];
    }
  }
}

enum BTShadowLevel { none, subtle, medium, strong }

class BTAcrylic {
  BTAcrylic._();

  static Color backgroundColor(BuildContext context, {double opacity = 0.7}) {
    var isDark = FluentTheme.of(context).brightness == Brightness.dark;
    return (isDark ? Colors.black : Colors.white).withValues(alpha: opacity);
  }

  static Color tintColor(BuildContext context) {
    var isDark = FluentTheme.of(context).brightness == Brightness.dark;
    return isDark ? const Color(0xFF202020) : const Color(0xFFF9F9F9);
  }

  static Color luminosityColor(BuildContext context) {
    var isDark = FluentTheme.of(context).brightness == Brightness.dark;
    return isDark
        ? Colors.black.withValues(alpha: 0.8)
        : Colors.white.withValues(alpha: 0.9);
  }

  static double get defaultBlurAmount => 20.0;

  static double get cardBlurAmount => 30.0;

  static Widget acrylicContainer({
    required BuildContext context,
    required Widget child,
    double blurAmount = 20.0,
    double opacity = 0.7,
    BorderRadius? borderRadius,
    EdgeInsetsGeometry? padding,
    EdgeInsetsGeometry? margin,
  }) {
    var isDark = FluentTheme.of(context).brightness == Brightness.dark;
    var bgColor = backgroundColor(context, opacity: opacity);

    Widget content = ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.circular(8.r),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurAmount, sigmaY: blurAmount),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: borderRadius ?? BorderRadius.circular(8.r),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.05),
              width: 1,
            ),
          ),
          child: child,
        ),
      ),
    );

    if (margin != null) {
      return Padding(padding: margin, child: content);
    }
    return content;
  }
}

class BTColors {
  BTColors._();

  static Color get success => const Color(0xFF107C10);

  static Color get warning => const Color(0xFFFFB900);

  static Color get error => const Color(0xFFD13438);

  static Color get info => const Color(0xFF0078D4);

  static Color successLight(BuildContext context) {
    var isDark = FluentTheme.of(context).brightness == Brightness.dark;
    return isDark ? const Color(0xFF6BBF6B) : const Color(0xFF107C10);
  }

  static Color warningLight(BuildContext context) {
    var isDark = FluentTheme.of(context).brightness == Brightness.dark;
    return isDark ? const Color(0xFFFFD75E) : const Color(0xFFFFB900);
  }

  static Color errorLight(BuildContext context) {
    var isDark = FluentTheme.of(context).brightness == Brightness.dark;
    return isDark ? const Color(0xFFFF6B6B) : const Color(0xFFD13438);
  }

  static Color surfacePrimary(BuildContext context) {
    var isDark = FluentTheme.of(context).brightness == Brightness.dark;
    return isDark ? const Color(0xFF1A1A1A) : const Color(0xFFFFFFFF);
  }

  static Color surfaceSecondary(BuildContext context) {
    var isDark = FluentTheme.of(context).brightness == Brightness.dark;
    return isDark ? const Color(0xFF252525) : const Color(0xFFF5F5F5);
  }

  static Color surfaceTertiary(BuildContext context) {
    var isDark = FluentTheme.of(context).brightness == Brightness.dark;
    return isDark ? const Color(0xFF303030) : const Color(0xFFEBEBEB);
  }

  static Color textPrimary(BuildContext context) {
    var isDark = FluentTheme.of(context).brightness == Brightness.dark;
    return isDark ? const Color(0xFFFFFFFF) : const Color(0xFF1A1A1A);
  }

  static Color textSecondary(BuildContext context) {
    var isDark = FluentTheme.of(context).brightness == Brightness.dark;
    return isDark ? const Color(0xFFB3B3B3) : const Color(0xFF666666);
  }

  static Color textTertiary(BuildContext context) {
    var isDark = FluentTheme.of(context).brightness == Brightness.dark;
    return isDark ? const Color(0xFF808080) : const Color(0xFF999999);
  }

  static Color divider(BuildContext context) {
    var isDark = FluentTheme.of(context).brightness == Brightness.dark;
    return isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.06);
  }
}

class BTDurations {
  BTDurations._();

  static const Duration fadeTransition = Duration(milliseconds: 200);
  static const Duration slideTransition = Duration(milliseconds: 250);
  static const Duration scaleTransition = Duration(milliseconds: 200);
  static const Duration pageTransition = Duration(milliseconds: 300);
  static const Duration hoverFeedback = Duration(milliseconds: 100);
  static const Duration pressFeedback = Duration(milliseconds: 50);
}

class BTRadius {
  BTRadius._();

  static double get none => 0;

  static double get small => 4.r;

  static double get medium => 8.r;

  static double get large => 12.r;

  static double get xlarge => 16.r;

  static double get xxlarge => 24.r;

  static double get round => 999.r;

  static BorderRadius get smallBR => BorderRadius.circular(small);

  static BorderRadius get mediumBR => BorderRadius.circular(medium);

  static BorderRadius get largeBR => BorderRadius.circular(large);

  static BorderRadius get xlargeBR => BorderRadius.circular(xlarge);

  static BorderRadius get xxlargeBR => BorderRadius.circular(xxlarge);

  static BorderRadius get roundBR => BorderRadius.circular(round);
}

class BTTypography {
  BTTypography._();

  static TextStyle caption(BuildContext context) {
    return TextStyle(
      fontSize: 12.sp,
      fontWeight: FontWeight.w400,
      color: BTColors.textSecondary(context),
    );
  }

  static TextStyle body(BuildContext context) {
    return TextStyle(
      fontSize: 14.sp,
      fontWeight: FontWeight.w400,
      color: BTColors.textPrimary(context),
    );
  }

  static TextStyle bodyStrong(BuildContext context) {
    return TextStyle(
      fontSize: 14.sp,
      fontWeight: FontWeight.w600,
      color: BTColors.textPrimary(context),
    );
  }

  static TextStyle subtitle(BuildContext context) {
    return TextStyle(
      fontSize: 16.sp,
      fontWeight: FontWeight.w600,
      color: BTColors.textPrimary(context),
    );
  }

  static TextStyle title(BuildContext context) {
    return TextStyle(
      fontSize: 20.sp,
      fontWeight: FontWeight.w600,
      color: BTColors.textPrimary(context),
    );
  }

  static TextStyle titleLarge(BuildContext context) {
    return TextStyle(
      fontSize: 24.sp,
      fontWeight: FontWeight.w700,
      color: BTColors.textPrimary(context),
    );
  }

  static TextStyle display(BuildContext context) {
    return TextStyle(
      fontSize: 32.sp,
      fontWeight: FontWeight.w700,
      color: BTColors.textPrimary(context),
    );
  }
}
