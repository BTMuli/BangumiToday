import 'dart:io';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

/// 文件工具
class BTFileTool {
  BTFileTool._();

  /// 获取应用数据目录
  static Future<String> getAppDataDir() async {
    var dir = await getApplicationDocumentsDirectory();
    return path.join(dir.path, 'BangumiToday');
  }

  /// 检测文件是否存在
  static Future<bool> isFileExist(String path) async {
    return File(path).exists();
  }

  /// 创建文件
  static Future<File> createFile(String path) async {
    return File(path).create(recursive: true);
  }

  /// 读取文件
  static Future<String> readFile(String path) async {
    if (await isFileExist(path)) {
      return File(path).readAsString();
    } else {
      debugPrint('File not exist: $path');
      return '';
    }
  }

  /// 写入文件
  static Future<File> writeFile(String path, String content) async {
    return File(path).writeAsString(content);
  }
}
