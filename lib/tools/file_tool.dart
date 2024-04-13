import 'dart:io';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

/// 文件工具
class BTFileTool {
  BTFileTool._();

  static final BTFileTool _instance = BTFileTool._();

  /// 获取实例
  factory BTFileTool() => _instance;

  /// 获取应用数据目录
  Future<String> getAppDataDir() async {
    var dir = await getApplicationDocumentsDirectory();
    return path.join(dir.path, 'BangumiToday');
  }

  /// 检测文件是否存在
  Future<bool> isFileExist(String path) async {
    return File(path).exists();
  }

  /// 创建文件
  Future<File> createFile(String path) async {
    return File(path).create(recursive: true);
  }

  /// 读取文件
  Future<String> readFile(String path) async {
    if (await _instance.isFileExist(path)) {
      return File(path).readAsString();
    } else {
      debugPrint('File not exist: $path');
      return '';
    }
  }

  /// 写入文件
  Future<File> writeFile(String path, String content) async {
    return File(path).writeAsString(content);
  }

  /// 检测目录是否存在
  Future<bool> isDirExist(String defaultPath) {
    return Directory(defaultPath).exists();
  }

  /// 创建目录
  Future<Directory> createDir(String defaultPath) {
    return Directory(defaultPath).create(recursive: true);
  }

  /// 获取目录下的文件名（不包括子目录）
  Future<List<String>> getFileNames(String dirPath) async {
    var dir = Directory(dirPath);
    if (await dir.exists()) {
      return dir.list().map((e) => path.basename(e.path)).toList();
    } else {
      return [];
    }
  }
}
