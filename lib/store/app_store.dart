// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:system_theme/system_theme.dart';

// Project imports:
import '../core/constants/app_constants.dart';
import '../database/app/app_config.dart';
import '../request/bangumi/bangumi_api.dart';

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
    initAccentColor();
    initMikanRss();
    initBangumiUrl();
  }

  /// 初始化主题
  Future<void> initTheme() async {
    _themeMode = await sqlite.readThemeMode();
    notifyListeners();
  }

  /// 初始化主题色
  Future<void> initAccentColor() async {
    _accentColor = await sqlite.readAccentColor();
    notifyListeners();
  }

  /// 初始化MikanRss
  Future<void> initMikanRss() async {
    _mikanRss = await sqlite.readMikanUrl();
    notifyListeners();
  }

  /// 初始化 Bangumi API 镜像地址
  Future<void> initBangumiUrl() async {
    _bangumiUrl = await sqlite.readBangumiUrl();
    BtrBangumiApi.setBaseUrl(_bangumiUrl);
    notifyListeners();
  }

  /// 主题
  ThemeMode _themeMode = ThemeMode.system;

  /// 主题色
  AccentColor _accentColor = Colors.blue.toAccentColor();

  /// MikanRss
  String? _mikanRss;

  /// Bangumi API 镜像地址
  String _bangumiUrl = BTAppConstants.bangumiApiBaseUrl;

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
  String? get mikanRss => _mikanRss;

  /// 设置MikanRss
  Future<void> setMikanRss(String value) async {
    _mikanRss = value;
    await sqlite.writeMikanUrl(value);
    notifyListeners();
  }

  /// 获取 Bangumi API 镜像地址
  String get bangumiUrl => _bangumiUrl;

  /// 设置 Bangumi API 镜像地址
  Future<void> setBangumiUrl(String value) async {
    BtrBangumiApi.setBaseUrl(value);
    _bangumiUrl = BtrBangumiApi.baseUrl;
    await sqlite.writeBangumiUrl(_bangumiUrl);
    notifyListeners();
  }
}
