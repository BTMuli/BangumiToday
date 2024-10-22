// Dart imports:
import 'dart:io';
import 'dart:typed_data';

// Package imports:
import 'package:crypto/crypto.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

// Project imports:
import '../ui/bt_infobar.dart';
import 'log_tool.dart';

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

  /// 获取相对应用数据目录的路径
  Future<String> getAppDataPath(String relativePath) async {
    var dir = await getAppDataDir();
    return path.join(dir, relativePath);
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
  Future<String?> readFile(String path) async {
    if (await _instance.isFileExist(path)) {
      return File(path).readAsString();
    } else {
      return null;
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

  /// 文件删除
  Future<bool> deleteFile(String path, {BuildContext? context}) async {
    var check = await isFileExist(path);
    if (!check) return true;
    try {
      await File(path).delete();
    } catch (e) {
      var errInfo = ['删除文件失败', '文件：$path', '错误：$e'];
      if (context != null && context.mounted) {
        await BtInfobar.error(context, errInfo.join('\n'));
      }
      BTLogTool.error(errInfo);
      return false;
    }
    return true;
  }

  /// 获取文件大小-调用FileStat
  int getFileSize(String path) {
    var stat = FileStat.statSync(path);
    return stat.size;
  }

  /// 打开目录
  Future<bool> openDir(String dirPath) async {
    var check = await isDirExist(dirPath);
    if (!check) return false;
    await Process.run('explorer', [dirPath]);
    return true;
  }

  /// 将unit8list写入文件并返回文件路径
  Future<String> writeTempImage(
    Uint8List data,
    String name,
    int progress,
  ) async {
    var dir = path.join(await getAppDataDir(), 'screenshots');
    await createDir(dir);
    var hashFile = md5.convert(name.codeUnits).toString();
    var file = File(path.join(dir, '${hashFile}_$progress.jpeg'));
    await file.writeAsBytes(data);
    return file.path;
  }

  /// 打开截图目录
  Future<void> openScreenshotDir() async {
    var dir = path.join(await getAppDataDir(), 'screenshots');
    await openDir(dir);
  }
}
