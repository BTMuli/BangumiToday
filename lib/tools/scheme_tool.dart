import 'dart:io';

import 'package:app_links/app_links.dart';
import 'package:win32_registry/win32_registry.dart';

import '../models/bangumi/oauth.dart';
import '../request/bangumi/bangumi_api.dart';
import '../request/bangumi/bangumi_oauth.dart';
import 'config_tool.dart';
import 'log_tool.dart';

/// 管理 APP 链接
class BTSchemeTool {
  BTSchemeTool._();

  /// 实例
  static final BTSchemeTool _instance = BTSchemeTool._();

  /// APP 链接
  static final AppLinks _appLinks = AppLinks();

  /// 获取实例
  factory BTSchemeTool() => _instance;

  /// 配置工具
  final BTConfigTool _configTool = BTConfigTool();

  /// 初始化
  Future<void> init() async {
    await _instance.register();
    BTLogTool.info('BTSchemeTool init');
    listen();
    BTLogTool.info('BTSchemeTool listening');
  }

  /// 注册链接
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

    final regKey = Registry.currentUser.createKey(protocolRegKey);
    regKey.createValue(protocolRegValue);
    regKey.createKey(protocolCmdRegKey).createValue(protocolCmdRegValue);
  }

  /// 监听
  void listen() {
    _appLinks.uriLinkStream.listen(uriHandler);
  }

  /// 处理链接
  void uriHandler(Uri uri) {
    if (uri.toString().startsWith('bangumitoday://oauth')) {
      handleOAuth(uri);
    }
  }

  /// 处理 OAuth 回调
  Future<void> handleOAuth(Uri uri) async {
    var code = uri.queryParameters['code'];
    if (code != null) {
      BTLogTool.info('OAuth code: $code');
    } else {
      throw Exception('OAuth code is null');
    }
    BTLogTool.info('OAuth path: ${uri.path}');
    final bangumiOauth = BangumiOauth();
    if (uri.path == "/bangumi/callback") {
      var res = await bangumiOauth.getAccessToken(code);
      BTLogTool.info('OAuth access token: ${res.accessToken}');
      await BangumiAPI().refreshGetAccessToken(token: res.accessToken);
      var oauthConfig = BangumiOauthConfig(
        appId: '',
        userId: res.userId,
        accessToken: res.accessToken,
        refreshToken: res.refreshToken,
        expiresIn: res.expiresIn,
      );
      var status = await bangumiOauth.getStatus(res.accessToken);
      BTLogTool.info('OAuth status: $status');
      oauthConfig.appId = status.clientId;
      _instance._configTool.writeConfig('bgm_oauth', oauthConfig.toJson());
      BTLogTool.info('OAuth success');
    }
  }
}
