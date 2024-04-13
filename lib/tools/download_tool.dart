import 'package:path/path.dart' as path;

import '../request/core/client.dart';
import 'file_tool.dart';
import 'log_tool.dart';

/// torrent 下载工具
class BTDownloadTool {
  BTDownloadTool._();

  /// 实例
  static final BTDownloadTool _instance = BTDownloadTool._();

  /// 默认 torrent 下载路径
  late String _defaultPath;

  /// 是否初始化
  late bool _isInit = false;

  /// 获取实例
  factory BTDownloadTool() => _instance;

  /// 文件工具
  final BTFileTool _fileTool = BTFileTool();

  /// 获取默认路径
  Future<String> _getDefaultPath() async {
    var dir = await _instance._fileTool.getAppDataDir();
    return path.join('$dir', 'download');
  }

  /// 初始化
  Future<void> init() async {
    if (_instance._isInit) {
      BTLogTool.info('BTDownloadTool has been initialized');
      return;
    }
    BTLogTool.info('BTDownloadTool init');
    _instance._defaultPath = await _instance._getDefaultPath();
    if (!await _instance._fileTool.isDirExist(_instance._defaultPath)) {
      BTLogTool.info('Create default download dir');
      await _instance._fileTool.createDir(_instance._defaultPath);
    }
    _instance._isInit = true;
  }

  /// 下载文件
  Future<String> downloadFile(String url, String savePath) async {
    if (!_instance._isInit) {
      BTLogTool.warn('BTDownloadTool has not been initialized');
      await _instance.init();
    }
    var saveDetailPath = path.join(_instance._defaultPath, '$savePath.torrent');
    var fileCheck = await _instance._fileTool.isFileExist(saveDetailPath);
    if (!fileCheck) {
      var client = BTRequestClient();
      await client.dio.download(url, saveDetailPath);
    }
    return saveDetailPath;
  }
}
