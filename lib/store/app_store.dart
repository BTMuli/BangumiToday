// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:system_theme/system_theme.dart';

// Project imports:
import '../core/constants/app_constants.dart';
import '../database/app/app_config.dart';
import '../request/bangumi/bangumi_api.dart';
import '../request/core/client.dart';
import '../request/mikan/mikan_api.dart';
import '../tools/log_tool.dart';

/// 应用状态提供者
final appStoreProvider = NotifierProvider<BTAppStore, BTAppSettings>(
  BTAppStore.new,
);

/// 应用设置状态：主题、镜像地址与开关。
///
/// 只保存可比较的配置值，SQLite 访问与客户端配置留在 [BTAppStore]。
class BTAppSettings {
  /// 构造函数
  const BTAppSettings({
    this.themeMode = ThemeMode.system,
    this.accentColor,
    this.mikanRss = BTAppConstants.defaultMikanMirror,
    this.bangumiUrl = BTAppConstants.bangumiApiBaseUrl,
    this.minimizeToTray = true,
    this.useSystemProxy = false,
    this.loaded = false,
  });

  /// 主题
  final ThemeMode themeMode;

  /// 主题色；为空表示使用系统主题色。
  final AccentColor? accentColor;

  /// MikanRss
  final String mikanRss;

  /// Bangumi API 镜像地址
  final String bangumiUrl;

  /// 关闭主窗口后是否隐藏到系统托盘。
  final bool minimizeToTray;

  /// 是否使用 Windows 系统代理。
  final bool useSystemProxy;

  /// 是否已从数据库读取完成。
  final bool loaded;

  /// 实际生效的主题色：系统主题模式下跟随系统。
  AccentColor get effectiveAccentColor {
    if (themeMode == ThemeMode.system) {
      return SystemTheme.accentColor.accent.toAccentColor();
    }
    return accentColor ?? Colors.blue.toAccentColor();
  }

  /// 拷贝
  BTAppSettings copyWith({
    ThemeMode? themeMode,
    AccentColor? accentColor,
    String? mikanRss,
    String? bangumiUrl,
    bool? minimizeToTray,
    bool? useSystemProxy,
    bool? loaded,
  }) {
    return BTAppSettings(
      themeMode: themeMode ?? this.themeMode,
      accentColor: accentColor ?? this.accentColor,
      mikanRss: mikanRss ?? this.mikanRss,
      bangumiUrl: bangumiUrl ?? this.bangumiUrl,
      minimizeToTray: minimizeToTray ?? this.minimizeToTray,
      useSystemProxy: useSystemProxy ?? this.useSystemProxy,
      loaded: loaded ?? this.loaded,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! BTAppSettings) return false;
    return themeMode == other.themeMode &&
        accentColor == other.accentColor &&
        mikanRss == other.mikanRss &&
        bangumiUrl == other.bangumiUrl &&
        minimizeToTray == other.minimizeToTray &&
        useSystemProxy == other.useSystemProxy &&
        loaded == other.loaded;
  }

  @override
  int get hashCode => Object.hash(
    themeMode,
    accentColor,
    mikanRss,
    bangumiUrl,
    minimizeToTray,
    useSystemProxy,
    loaded,
  );
}

/// 应用状态
class BTAppStore extends Notifier<BTAppSettings> {
  /// 应用配置数据库
  final BtsAppConfig sqlite = BtsAppConfig();

  bool _disposed = false;

  @override
  BTAppSettings build() {
    ref.onDispose(() => _disposed = true);
    // 设置是异步读取的，先给出默认值，读取完成后整体替换，避免逐项通知
    // 造成主题与镜像地址的中间态。
    Future.microtask(load);
    return const BTAppSettings();
  }

  /// 从数据库读取全部设置。
  Future<void> load() async {
    var themeMode = await sqlite.readThemeMode();
    var accentColor = await sqlite.readAccentColor();
    var minimizeToTray = await sqlite.readMinimizeToTray();
    var bangumiUrl = await sqlite.readBangumiUrl();
    var mikanRss = await sqlite.readMikanUrl();
    var useSystemProxy = await sqlite.readUseSystemProxy();

    BtrBangumiApi.setBaseUrl(bangumiUrl);
    BtrMikanApi.setBaseUrl(mikanRss);
    await BtrClient.configureSystemProxy(useSystemProxy);
    if (_disposed) return;

    state = BTAppSettings(
      themeMode: themeMode,
      accentColor: accentColor,
      mikanRss: BtrMikanApi.baseUrl,
      bangumiUrl: bangumiUrl,
      minimizeToTray: minimizeToTray,
      useSystemProxy: useSystemProxy,
      loaded: true,
    );
  }

  /// 设置主题：写入成功后才替换状态。
  Future<void> setThemeMode(ThemeMode value) async {
    await sqlite.writeThemeMode(value);
    state = state.copyWith(themeMode: value);
  }

  /// 设置主题色：写入成功后才替换状态。
  Future<void> setAccentColor(AccentColor value) async {
    await sqlite.writeAccentColor(value);
    state = state.copyWith(accentColor: value);
  }

  /// 设置MikanRss：写入成功后才替换状态。
  Future<void> setMikanRss(String value) async {
    BtrMikanApi.setBaseUrl(value);
    var normalized = BtrMikanApi.baseUrl;
    await sqlite.writeMikanUrl(normalized);
    state = state.copyWith(mikanRss: normalized);
  }

  /// 设置关闭后最小化到托盘配置。
  Future<void> setMinimizeToTray(bool value) async {
    await sqlite.writeMinimizeToTray(value);
    state = state.copyWith(minimizeToTray: value);
  }

  /// 设置是否使用系统代理；写入失败时回滚客户端配置并保留原状态。
  Future<void> setUseSystemProxy(bool value) async {
    var previous = state.useSystemProxy;
    try {
      await BtrClient.configureSystemProxy(value);
      await sqlite.writeUseSystemProxy(value);
    } catch (error, stackTrace) {
      try {
        await BtrClient.configureSystemProxy(previous);
      } catch (rollbackError) {
        BTLogTool.warn('回滚系统代理设置失败：$rollbackError');
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
    state = state.copyWith(useSystemProxy: value);
  }

  /// 设置 Bangumi API 镜像地址：写入成功后才替换状态。
  Future<void> setBangumiUrl(String value) async {
    BtrBangumiApi.setBaseUrl(value);
    var normalized = BtrBangumiApi.baseUrl;
    await sqlite.writeBangumiUrl(normalized);
    state = state.copyWith(bangumiUrl: normalized);
  }
}
