// Dart imports:
import 'dart:io';

// Package imports:
import 'package:flutter_acrylic/flutter_acrylic.dart';

/// 判断 Windows 版本是否支持系统 Mica 材质（Windows 11 build 22000+）。
///
/// [operatingSystemVersion] 用于测试注入；默认读取当前系统版本。
bool isMicaSupported({String? operatingSystemVersion}) {
  var version = operatingSystemVersion ?? Platform.operatingSystemVersion;
  var buildMatch = RegExp(
    r'Build (\d+)',
    caseSensitive: false,
  ).firstMatch(version);
  var build = int.tryParse(buildMatch?.group(1) ?? '');
  if (build != null) return build >= 22000;

  var legacyMatch = RegExp(r'Windows (\d+)\.(\d+)\.(\d+)').firstMatch(version);
  if (legacyMatch == null) return false;
  var legacyBuild = int.tryParse(legacyMatch.group(3) ?? '');
  return legacyBuild != null && legacyBuild >= 22000;
}

/// 应用窗口背景材质：优先 Mica，不支持的旧系统回退 Acrylic。
///
/// [dark] 控制深浅色模式，Mica 与新版 Acrylic 会同步窗口标题栏。
Future<void> applyWindowMaterial({required bool dark}) {
  return Window.setEffect(
    effect: isMicaSupported() ? WindowEffect.mica : WindowEffect.acrylic,
    dark: dark,
  );
}
