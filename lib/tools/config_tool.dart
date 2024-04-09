import 'dart:convert';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:path/path.dart' as path;

import 'file_tool.dart';
import 'log_tool.dart';

/// 配置工具
class BTConfigTool {
  BTConfigTool._();

  /// 实例
  static final BTConfigTool _instance = BTConfigTool._();

  /// 默认路径
  late String _defaultPath;

  /// 是否初始化
  late bool _isInit = false;

  /// 配置
  late Map<String, dynamic> _config = {};

  /// 获取实例
  factory BTConfigTool() => _instance;

  /// 文件工具
  final BTFileTool _fileTool = BTFileTool();

  /// 获取默认路径
  Future<String> _getDefaultPath() async {
    var dir = await _instance._fileTool.getAppDataDir();
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
  Future<void> init() async {
    if (_instance._isInit) {
      BTLogTool.info('BTConfigTool has been initialized');
      return;
    }
    BTLogTool.info('BTConfigTool init');
    _instance._defaultPath = await _instance._getDefaultPath();
    if (!await _instance._fileTool.isFileExist(_instance._defaultPath)) {
      BTLogTool.info('Create default config file');
      await _instance._fileTool.createFile(_instance._defaultPath);
      await _instance._fileTool.writeFile(
        _instance._defaultPath,
        _getDefaultConfig(),
      );
      _instance._config = jsonDecode(_getDefaultConfig());
    } else {
      BTLogTool.info('Load config file');
      var content = await _instance._fileTool.readFile(_instance._defaultPath);
      if (content.isNotEmpty) {
        try {
          _instance._config = jsonDecode(content);
          BTLogTool.info('Load config file success');
          BTLogTool.info('Config: ${_instance._config}');
        } on FormatException catch (e) {
          BTLogTool.error('Load config file failed: $e');
          BTLogTool.error('Use default config');
          _instance._config = jsonDecode(_getDefaultConfig());
        }
      } else {
        BTLogTool.error('Load config file failed, file is empty');
        BTLogTool.warn('Use default config');
        _instance._config = jsonDecode(_getDefaultConfig());
      }
    }
    _instance._isInit = true;
    BTLogTool.info('BTConfigTool init success');
  }

  /// 读取配置
  dynamic readConfig({String? key}) {
    if (!_instance._isInit) {
      BTLogTool.warn('BTConfigTool has not been initialized');
      return null;
    }
    if (key == null) {
      BTLogTool.info('Read all config');
      return _instance._config;
    }
    if (!_instance._config.containsKey(key)) {
      BTLogTool.error('Config key not found: $key');
      return null;
    }
    BTLogTool.info('Read config: $key');
    return _instance._config[key];
  }

  /// 写入配置
  Future<void> writeConfig(String key, dynamic value) async {
    if (!_instance._isInit) {
      BTLogTool.warn('BTConfigTool has not been initialized');
      await _instance.init();
    }
    if (!_instance._config.containsKey(key)) {
      BTLogTool.warn('Config key not found: $key');
      BTLogTool.info('Create new config: $key, $value');
      _instance._config[key] = value;
    } else {
      BTLogTool.info('Update config: $key, $value');
      _instance._config[key] = value;
    }
    await _instance._fileTool.writeFile(
      _instance._defaultPath,
      jsonEncode(_instance._config),
    );
  }
}
