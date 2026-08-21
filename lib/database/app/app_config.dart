// Dart imports:
import 'dart:convert';

// Package imports:
import 'package:fluent_ui/fluent_ui.dart';

// Project imports:
import '../../core/constants/app_constants.dart';
import '../../models/app/bt_download_config.dart';
import '../../models/app/bt_tracker_config.dart';
import '../../tools/log_tool.dart';
import '../bt_sqlite.dart';

/// 应用配置
class BtsAppConfig {
  BtsAppConfig._();

  /// 实例
  static final BtsAppConfig _instance = BtsAppConfig._();

  /// 获取实例
  factory BtsAppConfig() => _instance;

  /// 数据库
  final BTSqlite sqlite = BTSqlite();

  /// 表名
  final String _tableName = 'AppConfig';

  /// 前置检查-通用
  Future<void> preCheck() async {
    var check = await _instance.sqlite.isTableExist(_instance._tableName);
    if (!check) {
      await _instance.sqlite.db.execute('''
        CREATE TABLE $_tableName (
          key TEXT NOT NULL PRIMARY KEY,
          value TEXT NOT NULL
        );
      ''');
      BTLogTool.info('Create table $_tableName');
    }
  }

  /// 读取配置-通用
  Future<String?> read(String key) async {
    await _instance.preCheck();
    var result = await _instance.sqlite.db.query(
      _tableName,
      where: 'key = ?',
      whereArgs: [key],
    );
    if (result.isEmpty) return '';
    var value = result.first['value'];
    BTLogTool.info('Read config: $key');
    return value.toString();
  }

  /// 写入/更新配置-通用
  Future<void> write(String key, String value) async {
    await _instance.preCheck();
    var result = await _instance.sqlite.db.query(
      _tableName,
      where: 'key = ?',
      whereArgs: [key],
    );
    if (result.isEmpty) {
      await _instance.sqlite.db.insert(_tableName, {
        'key': key,
        'value': value,
      });
      BTLogTool.info('Write config: $key');
    } else {
      await _instance.sqlite.db.update(
        _tableName,
        {'value': value},
        where: 'key = ?',
        whereArgs: [key],
      );
    }
    BTLogTool.info('Update config: $key');
  }

  /// 删除配置-通用
  Future<void> delete(String key) async {
    await _instance.preCheck();
    await _instance.sqlite.db.delete(
      _tableName,
      where: 'key = ?',
      whereArgs: [key],
    );
    BTLogTool.info('Delete config: $key');
  }

  /// 读取主题模式配置
  Future<ThemeMode> readThemeMode() async {
    var res = await _instance.read('themeMode');
    var defaultValue = ThemeMode.system;
    if (res == null || res.isEmpty) {
      await _instance.writeThemeMode(defaultValue);
      return defaultValue;
    }
    const allowList = ["ThemeMode.system", "ThemeMode.light", "ThemeMode.dark"];
    if (!allowList.contains(res)) {
      BTLogTool.warn('Invalid theme mode: $res');
      await _instance.writeThemeMode(defaultValue);
      return defaultValue;
    }
    switch (res) {
      case 'ThemeMode.system':
        return ThemeMode.system;
      case 'ThemeMode.light':
        return ThemeMode.light;
      case 'ThemeMode.dark':
        return ThemeMode.dark;
    }
    return defaultValue;
  }

  /// 写/更新主题模式配置
  Future<void> writeThemeMode(ThemeMode value) async {
    await _instance.write('themeMode', value.toString());
  }

  /// 读取主题色配置
  Future<AccentColor> readAccentColor() async {
    var res = await _instance.read('accentColor');
    var defaultValue = Colors.blue.toAccentColor();
    if (res == null || res.isEmpty) {
      await _instance.writeAccentColor(defaultValue);
      return defaultValue;
    }
    var trans = int.tryParse(res);
    if (trans == null || trans.isNaN) {
      BTLogTool.warn('Invalid accent color: $res');
      await _instance.writeAccentColor(defaultValue);
      return defaultValue;
    }
    return Color(trans).toAccentColor();
  }

  /// 写/更新主题色配置
  Future<void> writeAccentColor(AccentColor value) async {
    await _instance.write('accentColor', value.colorValue.toString());
  }

  /// 读取关闭后最小化到托盘配置。
  ///
  /// 新配置默认开启，保证旧版本升级后仍能使用托盘恢复窗口。
  Future<bool> readMinimizeToTray() async {
    const defaultValue = true;
    var value = await _instance.read('minimizeToTray');
    if (value == null || value.isEmpty) {
      await _instance.writeMinimizeToTray(defaultValue);
      return defaultValue;
    }
    if (value == 'true') return true;
    if (value == 'false') return false;

    BTLogTool.warn('Invalid minimize-to-tray config: $value');
    await _instance.writeMinimizeToTray(defaultValue);
    return defaultValue;
  }

  /// 写入关闭后最小化到托盘配置。
  Future<void> writeMinimizeToTray(bool value) async {
    await _instance.write('minimizeToTray', value.toString());
  }

  /// 读取是否使用系统代理配置。
  Future<bool> readUseSystemProxy() async {
    const defaultValue = false;
    var value = await _instance.read('useSystemProxy');
    if (value == null || value.isEmpty) {
      await _instance.writeUseSystemProxy(defaultValue);
      return defaultValue;
    }
    if (value == 'true') return true;
    if (value == 'false') return false;

    BTLogTool.warn('Invalid system proxy config: $value');
    await _instance.writeUseSystemProxy(defaultValue);
    return defaultValue;
  }

  /// 写入是否使用系统代理配置。
  Future<void> writeUseSystemProxy(bool value) async {
    await _instance.write('useSystemProxy', value.toString());
  }

  /// 读取 bangumiDataVersion
  Future<String?> readBangumiDataVersion() async {
    return _instance.read('bangumiDataVersion');
  }

  /// 写入/更新 bangumiDataVersion
  Future<void> writeBangumiDataVersion(String version) async {
    await _instance.write('bangumiDataVersion', version);
  }

  /// 读取 bangumiDataCheckTime
  Future<String?> readBangumiDataCheckTime() async {
    return _instance.read('bangumiDataCheckTime');
  }

  /// 写入/更新 bangumiDataCheckTime
  Future<void> writeBangumiDataCheckTime(String time) async {
    await _instance.write('bangumiDataCheckTime', time);
  }

  /// 读取 mikan url
  Future<String> readMikanUrl() async {
    var res = await _instance.read('mikanUrl');
    var normalized = BTAppConstants.normalizeMikanUrl(res);
    if (res != normalized) {
      if (res != null && res.isNotEmpty) {
        BTLogTool.warn('Normalize Mikan URL: $res -> $normalized');
      }
      await _instance.writeMikanUrl(normalized);
    }
    return normalized;
  }

  /// 写入/更新 mikan url
  Future<void> writeMikanUrl(String url) async {
    await _instance.write('mikanUrl', BTAppConstants.normalizeMikanUrl(url));
  }

  /// 读取 Bangumi API 镜像地址
  Future<String> readBangumiUrl() async {
    var res = await _instance.read('bangumiUrl');
    var isSupported =
        res == BTAppConstants.bangumiApiBaseUrl ||
        res == BTAppConstants.bangumiLolApiBaseUrl ||
        res == BTAppConstants.officialBangumiApiBaseUrl;
    if (!isSupported) {
      if (res != null && res.isNotEmpty) {
        BTLogTool.warn('Invalid Bangumi API URL: $res');
      }
      res = BTAppConstants.bangumiApiBaseUrl;
      await _instance.writeBangumiUrl(res);
    }
    return res!;
  }

  /// 写入/更新 Bangumi API 镜像地址
  Future<void> writeBangumiUrl(String url) async {
    await _instance.write('bangumiUrl', url);
  }

  Future<BtDownloadConfig> readBtDownloadConfig() async {
    var value = await _instance.read('btDownloadConfig');
    if (value == null || value.isEmpty) {
      const config = BtDownloadConfig.freshInstall();
      await writeBtDownloadConfig(config);
      return config;
    }
    try {
      var decoded = jsonDecode(value);
      if (decoded is! Map) {
        throw const FormatException('config is not an object');
      }
      return BtDownloadConfig.fromJson(Map<String, dynamic>.from(decoded));
    } catch (error) {
      BTLogTool.warn('Invalid BT download config: $error');
      const config = BtDownloadConfig();
      await writeBtDownloadConfig(config);
      return config;
    }
  }

  Future<void> writeBtDownloadConfig(BtDownloadConfig config) async {
    config.validate();
    await _instance.write('btDownloadConfig', jsonEncode(config.toJson()));
  }

  Future<BtTrackerConfig> readBtTrackerConfig() async {
    var value = await _instance.read('btTrackerConfig');
    if (value == null || value.isEmpty) {
      const config = BtTrackerConfig();
      await writeBtTrackerConfig(config);
      return config;
    }
    try {
      var decoded = jsonDecode(value);
      if (decoded is! Map) {
        throw const FormatException('config is not an object');
      }
      return BtTrackerConfig.fromJson(Map<String, dynamic>.from(decoded));
    } catch (error) {
      BTLogTool.warn('Invalid BT Tracker config: $error');
      const config = BtTrackerConfig();
      await writeBtTrackerConfig(config);
      return config;
    }
  }

  Future<void> writeBtTrackerConfig(BtTrackerConfig config) async {
    config.validate();
    await _instance.write('btTrackerConfig', jsonEncode(config.toJson()));
  }

  /// 读取条目详情布局。空值表示尚未选择，由调用方使用默认布局。
  Future<String> readSubjectDetailLayout() async {
    var value = await _instance.read('subjectDetailLayout');
    if (value == null || value.isEmpty) return '';
    return value;
  }

  /// 写入条目详情布局。
  Future<void> writeSubjectDetailLayout(String value) async {
    await _instance.write('subjectDetailLayout', value);
  }
}
