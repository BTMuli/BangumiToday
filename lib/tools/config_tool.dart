import 'dart:convert';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:path/path.dart' as path;

import 'file_tool.dart';
import 'log_tool.dart';

/// 配置工具
class BTConfigTool {
  BTConfigTool._();

  static late String _defaultPath;
  static late bool _isInit = false;
  static Map<String, dynamic> _config = {};

  /// 获取默认路径
  static Future<String> _getDefaultPath() async {
    var dir = await BTFileTool.getAppDataDir();
    return path.join('$dir', 'app', 'config.json');
  }

  /// 获取默认配置
  static String _getDefaultConfig() {
    var defaultConfig = {
      'themeMode': ThemeMode.system.toString(),
      'accentColor': Colors.blue.toAccentColor().value,
      'language': 'zh',
      'source': 'bangumi',
    };
    return jsonEncode(defaultConfig);
  }

  /// 初始化
  static Future<void> init() async {
    if (_isInit) {
      BTLogTool.info('BTConfigTool has been initialized');
      return;
    }
    BTLogTool.info('BTConfigTool init');
    _defaultPath = await _getDefaultPath();
    if (!await BTFileTool.isFileExist(_defaultPath)) {
      BTLogTool.info('Create default config file');
      await BTFileTool.createFile(_defaultPath);
      await BTFileTool.writeFile(_defaultPath, _getDefaultConfig());
      _config = jsonDecode(_getDefaultConfig());
    } else {
      BTLogTool.info('Load config file');
      var content = await BTFileTool.readFile(_defaultPath);
      if (content.isNotEmpty) {
        try {
          _config = jsonDecode(content);
          BTLogTool.info('Load config file success');
          BTLogTool.info('Config: $_config');
        } on FormatException catch (e) {
          BTLogTool.error('Load config file failed: $e');
          BTLogTool.error('Use default config');
          _config = jsonDecode(_getDefaultConfig());
        }
      } else {
        BTLogTool.error('Load config file failed, file is empty');
        BTLogTool.warn('Use default config');
        _config = jsonDecode(_getDefaultConfig());
      }
    }
    _isInit = true;
    BTLogTool.info('BTConfigTool init success');
  }

  /// 读取配置
  static dynamic readConfig({String? key}) {
    if (!_isInit) {
      BTLogTool.warn('BTConfigTool has not been initialized');
      return null;
    }
    if (key == null) {
      BTLogTool.info('Read all config');
      return _config;
    }
    if (!_config.containsKey(key)) {
      BTLogTool.error('Config key not found: $key');
      return null;
    }
    BTLogTool.info('Read config: $key');
    return _config[key];
  }

  /// 写入配置
  static Future<void> writeConfig(String key, dynamic value) async {
    if (!_isInit) {
      BTLogTool.warn('BTConfigTool has not been initialized');
      await init();
    }
    if (!_config.containsKey(key)) {
      BTLogTool.warn('Config key not found: $key');
      BTLogTool.info('Create new config: $key, $value');
      _config[key] = value;
    } else {
      BTLogTool.info('Update config: $key, $value');
      _config[key] = value;
    }
    await BTFileTool.writeFile(_defaultPath, jsonEncode(_config));
  }

  /// 写入主题模式
  static Future<void> writeConfigThemeMode(ThemeMode value) async {
    await writeConfig('themeMode', value.toString());
  }

  /// 写入主题色
  static Future<void> writeConfigAccentColor(AccentColor value) async {
    await writeConfig('accentColor', value.value);
  }

  /// 写入番剧数据源
  static Future<void> writeConfigSource(String value) async {
    await writeConfig('source', value);
  }

  /// 读取主题模式
  static String readConfigThemeMode() {
    return readConfig(key: 'themeMode');
  }

  /// 读取主题色
  static int readConfigAccentColor() {
    return readConfig(key: 'accentColor');
  }

  /// 读取番剧数据源
  static String readConfigSource() {
    return readConfig(key: 'source');
  }
}
