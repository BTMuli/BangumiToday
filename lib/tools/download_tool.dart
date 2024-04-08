import 'package:path/path.dart' as path;

import '../request/core/client.dart';
import 'config_tool.dart';
import 'file_tool.dart';
import 'log_tool.dart';

/// torrent 下载工具
class BTDownloadTool {
  BTDownloadTool._();

  /// 默认 torrent 下载路径
  static late String _defaultPath;

  /// 默认番剧保存路径
  static late String _defaultBgmPath;

  /// 获取保存路径
  static String get defaultBgmPath => _defaultBgmPath;

  /// 是否初始化
  static late bool _isInit = false;

  /// 获取默认路径
  static Future<String> _getDefaultPath() async {
    var dir = await BTFileTool.getAppDataDir();
    return path.join('$dir', 'download');
  }

  /// 获取默认番剧路径
  static Future<String> _getDefaultBgmPath() async {
    // 尝试读取配置文件
    var config = await BTConfigTool.readConfig(key: 'download_dir');
    if (config == null) {
      // 读取失败，使用默认路径
      return path.join(_defaultPath, 'bangumi');
    } else {
      // 读取成功，使用配置路径
      return config;
    }
  }

  /// 检测是否已经初始化
  static bool get isInit => _isInit;

  /// 初始化
  static Future<void> init() async {
    if (_isInit) {
      BTLogTool.info('BTDownloadTool has been initialized');
      return;
    }
    BTLogTool.info('BTDownloadTool init');
    _defaultPath = await _getDefaultPath();
    if (!await BTFileTool.isDirExist(_defaultPath)) {
      BTLogTool.info('Create default download dir');
      await BTFileTool.createDir(_defaultPath);
    }
    _defaultBgmPath = await _getDefaultBgmPath();
    if (!await BTFileTool.isDirExist(_defaultBgmPath)) {
      BTLogTool.info('Create default bangumi dir');
      await BTFileTool.createDir(_defaultBgmPath);
    }
    _isInit = true;
  }

  /// 下载文件
  static Future<String> downloadFile(String url, String savePath) async {
    if (!_isInit) {
      BTLogTool.error('BTDownloadTool has not been initialized');
      return '';
    }
    var client = BTRequestClient();
    var saveDetailPath = path.join(_defaultPath, '$savePath.torrent');
    await client.dio.download(url, saveDetailPath);
    return saveDetailPath;
  }
}
