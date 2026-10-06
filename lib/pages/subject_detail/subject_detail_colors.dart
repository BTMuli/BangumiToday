// Package imports:
import 'package:fluent_ui/fluent_ui.dart';

/// 详情页采用逐层略亮的表面，避免正文区域与概览形成过深的反差。
class SubjectDetailColors {
  SubjectDetailColors._();

  static Color content(BuildContext context) =>
      FluentTheme.of(context).brightness == Brightness.dark
      ? const Color(0xFF2B2B2B)
      : const Color(0xFFF5F5F5);

  static Color card(BuildContext context) =>
      FluentTheme.of(context).brightness == Brightness.dark
      ? const Color(0xFF333333)
      : const Color(0xFFFFFFFF);
}
