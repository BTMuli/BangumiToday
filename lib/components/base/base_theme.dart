// Package imports:
import 'package:fluent_ui/fluent_ui.dart';

/// 主题色枚举
enum BaseThemeColor {
  /// base
  base,

  /// light
  light,

  /// dark
  dark,

  /// lighter
  lighter,

  /// darker
  darker,

  /// lightest
  lightest,

  /// darkest
  darkest,
}

/// 根据主题颜色获取颜色
Color getColor(AccentColor base, BaseThemeColor color) {
  switch (color) {
    case BaseThemeColor.base:
      return base;
    case BaseThemeColor.light:
      return base.light;
    case BaseThemeColor.dark:
      return base.dark;
    case BaseThemeColor.lighter:
      return base.lighter;
    case BaseThemeColor.darker:
      return base.darker;
    case BaseThemeColor.lightest:
      return base.lightest;
    case BaseThemeColor.darkest:
      return base.darkest;
  }
}
