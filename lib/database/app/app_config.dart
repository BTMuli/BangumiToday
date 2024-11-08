// Package imports:
import 'package:fluent_ui/fluent_ui.dart';

// Project imports:
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
    BTLogTool.info('Read config: $key = $value');
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
      await _instance.sqlite.db.insert(
        _tableName,
        {'key': key, 'value': value},
      );
      BTLogTool.info('Write config: $key = $value');
    } else {
      await _instance.sqlite.db.update(
        _tableName,
        {'value': value},
        where: 'key = ?',
        whereArgs: [key],
      );
    }
    BTLogTool.info('Update config: $key = $value');
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
    await _instance.write('accentColor', value.value.toString());
  }

  /// 读取 mikan token
  Future<String?> readMikanToken() async {
    return _instance.read('mikanToken');
  }

  /// 写入/更新 mikan token
  Future<void> writeMikanToken(String token) async {
    await _instance.write('mikanToken', token);
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
}
