// Dart imports:
import 'dart:io';

// Flutter imports:
import 'package:flutter/foundation.dart';

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

/// 本窗口的材质通道是否已初始化。
///
/// `Window.setEffect` 会等待 `Window.initialize` 完成；初始化失败后再调用它会
/// 一直挂起，所以这里记下结果，让调用方能在材质不可用时退回不透明底色。
bool _materialReady = false;

/// 当前窗口是否已有可用的背景材质。
///
/// 每个独立窗口都有自己的引擎与插件注册，这个状态是各窗口独立的。
bool get windowMaterialReady => _materialReady;

/// 初始化本窗口的材质通道，返回材质是否可用。
///
/// 必须在每个窗口各自的入口调用一次；失败只影响窗口底色，不抛出异常。
Future<bool> initializeWindowMaterial() async {
  try {
    await Window.initialize();
    _materialReady = true;
  } catch (error) {
    debugPrint('窗口材质初始化失败: $error');
  }
  return _materialReady;
}

/// 应用窗口背景材质：优先 Mica，不支持的旧系统回退 Acrylic。
///
/// [dark] 控制深浅色模式，Mica 与新版 Acrylic 会同步窗口标题栏。
Future<void> applyWindowMaterial({required bool dark}) {
  if (!_materialReady) return Future<void>.value();
  return Window.setEffect(
    effect: isMicaSupported() ? WindowEffect.mica : WindowEffect.acrylic,
    dark: dark,
  );
}
