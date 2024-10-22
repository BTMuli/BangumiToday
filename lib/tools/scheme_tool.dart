// Dart imports:
import 'dart:io';

// Package imports:
import 'package:app_links/app_links.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:win32_registry/win32_registry.dart';

// Project imports:
import '../ui/bt_infobar.dart';
import 'log_tool.dart';

/// 管理 APP 链接
class BTSchemeTool {
  BTSchemeTool._();

  /// 实例
  static final BTSchemeTool _instance = BTSchemeTool._();

  /// 获取实例
  factory BTSchemeTool() => _instance;

  /// appLink 监听
  final appLink = AppLinks();

  /// 初始化
  Future<void> init() async {
    await _instance.register();
    BTLogTool.info('BTSchemeTool init');
  }

  /// 测试
  Future<void> test(BuildContext context) async {
    var uri = await appLink.getLatestLink();
    if (context.mounted) {
      await BtInfobar.success(context, '[BangumiToday] $uri');
    }
  }

  /// 注册链接
  /// 该部分可以交给msix打包工具自动注册
  Future<void> register() async {
    var appPath = Platform.resolvedExecutable;
    var protocolRegKey = 'Software\\Classes\\BangumiToday';
    var protocolRegValue = const RegistryValue(
      'URL Protocol',
      RegistryValueType.string,
      '',
    );
    var protocolCmdRegKey = 'shell\\open\\command';
    var protocolCmdRegValue = RegistryValue(
      '',
      RegistryValueType.string,
      '"$appPath" "%1"',
    );

    var regKey = Registry.currentUser.createKey(protocolRegKey);
    regKey.createValue(protocolRegValue);
    regKey.createKey(protocolCmdRegKey).createValue(protocolCmdRegValue);
  }
}
