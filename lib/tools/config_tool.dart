import 'dart:convert';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:path/path.dart' as path;

import 'file_tool.dart';

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
    };
    return jsonEncode(defaultConfig);
  }

  /// 初始化
  static Future<void> init() async {
    if (_isInit) {
      debugPrint('BTConfigTool has been initialized');
      return;
    }
    debugPrint('BTConfigTool init');
    _defaultPath = await _getDefaultPath();
    if (!await BTFileTool.isFileExist(_defaultPath)) {
      debugPrint('Create default config file');
      await BTFileTool.createFile(_defaultPath);
      await BTFileTool.writeFile(_defaultPath, _getDefaultConfig());
      _config = jsonDecode(_getDefaultConfig());
    } else {
      debugPrint('Load config file');
      var content = await BTFileTool.readFile(_defaultPath);
      if (content.isNotEmpty) {
        try {
          _config = jsonDecode(content);
          debugPrint('Load config file success');
          debugPrint('Config: $_config');
        } on FormatException catch (e) {
          debugPrint('Load config file failed: $e');
          debugPrint('Use default config');
          _config = jsonDecode(_getDefaultConfig());
        }
      } else {
        debugPrint('Load config file failed, file is empty');
        debugPrint('Use default config');
        _config = jsonDecode(_getDefaultConfig());
      }
    }
    _isInit = true;
    debugPrint('BTConfigTool init success');
  }

  /// 读取配置
  static dynamic readConfig({String? key}) {
    if (!_isInit) {
      debugPrint('BTConfigTool has not been initialized');
      return null;
    }
    if (key == null) {
      debugPrint('Read all config');
      return _config;
    }
    if (!_config.containsKey(key)) {
      debugPrint('Config key not found: $key');
      return null;
    }
    debugPrint('Read config: $key');
    return _config[key];
  }

  /// 写入配置
  static Future<void> writeConfig(String key, dynamic value) async {
    if (!_isInit) {
      debugPrint('BTConfigTool has not been initialized');
      await init();
    }
    if (!_config.containsKey(key)) {
      debugPrint('Config key not found: $key');
      debugPrint('Create new config: $key, $value');
      _config[key] = value;
    } else {
      debugPrint('Update config: $key, $value');
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
}
