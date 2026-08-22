// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:system_theme/system_theme.dart';

// Project imports:
import '../core/constants/app_constants.dart';
import '../core/network/system_proxy.dart';
import '../core/services/bt_engine_client.dart';
import '../database/app/app_config.dart';
import '../plugins/mikan/mikan_api.dart';
import '../request/bangumi/bangumi_api.dart';
import '../request/core/client.dart';
import '../tools/log_tool.dart';

/// 应用状态提供者
final appStoreProvider = ChangeNotifierProvider<BTAppStore>((ref) {
  return BTAppStore();
});

/// 应用状态
class BTAppStore extends ChangeNotifier {
  /// 应用配置数据库
  final BtsAppConfig sqlite = BtsAppConfig();

  /// 构造函数
  BTAppStore() {
    initTheme();
    initMinimizeToTray();
    initMikanRss();
    initBangumiUrl();
    initUseSystemProxy();
  }

  /// 初始化主题和主题色
  Future<void> initTheme() async {
    var themeMode = await sqlite.readThemeMode();
    var accentColor = await sqlite.readAccentColor();
    _themeMode = themeMode;
    _accentColor = accentColor;
    notifyListeners();
  }

  /// 初始化关闭后最小化到托盘配置。
  Future<void> initMinimizeToTray() async {
    _minimizeToTray = await sqlite.readMinimizeToTray();
    notifyListeners();
  }

  /// 初始化MikanRss
  Future<void> initMikanRss() async {
    BtrMikanApi.setBaseUrl(await sqlite.readMikanUrl());
    _mikanRss = BtrMikanApi.baseUrl;
    notifyListeners();
  }

  /// 初始化 Bangumi API 镜像地址
  Future<void> initBangumiUrl() async {
    _bangumiUrl = await sqlite.readBangumiUrl();
    BtrBangumiApi.setBaseUrl(_bangumiUrl);
    notifyListeners();
  }

  /// 初始化系统代理配置。
  Future<void> initUseSystemProxy() async {
    _useSystemProxy = await sqlite.readUseSystemProxy();
    await BtrClient.configureSystemProxy(_useSystemProxy);
    await _syncDownloadEngineProxy();
    notifyListeners();
  }

  /// 主题
  ThemeMode _themeMode = ThemeMode.system;

  /// 主题色
  AccentColor _accentColor = Colors.blue.toAccentColor();

  /// MikanRss
  String _mikanRss = BTAppConstants.defaultMikanMirror;

  /// Bangumi API 镜像地址
  String _bangumiUrl = BTAppConstants.bangumiApiBaseUrl;

  /// 关闭主窗口后是否隐藏到系统托盘。
  bool _minimizeToTray = true;

  /// 是否使用 Windows 系统代理。
  bool _useSystemProxy = false;

  /// 获取主题
  ThemeMode get themeMode => _themeMode;

  /// 设置主题
  Future<void> setThemeMode(ThemeMode value) async {
    _themeMode = value;
    await sqlite.writeThemeMode(value);
    notifyListeners();
  }

  /// 获取主题色
  AccentColor get accentColor {
    if (_themeMode == ThemeMode.system) {
      return SystemTheme.accentColor.accent.toAccentColor();
    } else {
      return _accentColor;
    }
  }

  /// 设置主题色
  Future<void> setAccentColor(AccentColor value) async {
    _accentColor = value;
    await sqlite.writeAccentColor(value);
    notifyListeners();
  }

  /// 获取MikanRss
  String get mikanRss => _mikanRss;

  /// 设置MikanRss
  Future<void> setMikanRss(String value) async {
    BtrMikanApi.setBaseUrl(value);
    _mikanRss = BtrMikanApi.baseUrl;
    await sqlite.writeMikanUrl(_mikanRss);
    notifyListeners();
  }

  /// 获取 Bangumi API 镜像地址
  String get bangumiUrl => _bangumiUrl;

  /// 获取关闭后最小化到托盘配置。
  bool get minimizeToTray => _minimizeToTray;

  /// 获取是否使用系统代理。
  bool get useSystemProxy => _useSystemProxy;

  /// 设置关闭后最小化到托盘配置。
  Future<void> setMinimizeToTray(bool value) async {
    _minimizeToTray = value;
    await sqlite.writeMinimizeToTray(value);
    notifyListeners();
  }

  /// 设置是否使用系统代理。
  Future<void> setUseSystemProxy(bool value) async {
    var previous = _useSystemProxy;
    try {
      await BtrClient.configureSystemProxy(value);
      await _syncDownloadEngineProxy();
      await sqlite.writeUseSystemProxy(value);
    } catch (error, stackTrace) {
      try {
        await BtrClient.configureSystemProxy(previous);
        await _syncDownloadEngineProxy();
      } catch (rollbackError) {
        BTLogTool.warn('回滚系统代理设置失败：$rollbackError');
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
    _useSystemProxy = value;
    notifyListeners();
  }

  Future<void> _syncDownloadEngineProxy() async {
    var engine = BtEngineClient.instance;
    if (!engine.isReady) return;
    await engine.configureProxy(SystemProxyController.engineProxyConfig);
  }

  /// 设置 Bangumi API 镜像地址
  Future<void> setBangumiUrl(String value) async {
    BtrBangumiApi.setBaseUrl(value);
    _bangumiUrl = BtrBangumiApi.baseUrl;
    await sqlite.writeBangumiUrl(_bangumiUrl);
    notifyListeners();
  }
}
