import 'package:path/path.dart' as path;

import '../request/core/client.dart';
import 'file_tool.dart';
import 'log_tool.dart';

/// torrent 下载工具
class BTDownloadTool {
  BTDownloadTool._();

  static late String _defaultPath;
  static late bool _isInit = false;

  /// 获取默认路径
  static Future<String> _getDefaultPath() async {
    var dir = await BTFileTool.getAppDataDir();
    return path.join('$dir', 'download');
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
