// Package imports:
import 'package:dio/dio.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:path/path.dart' as path;

// Project imports:
import '../components/app/app_dialog_resp.dart';
import '../components/app/app_infobar.dart';
import '../models/app/response.dart';
import '../request/core/client.dart';
import 'file_tool.dart';
import 'log_tool.dart';

/// torrent 下载工具
class BTDownloadTool {
  BTDownloadTool._();

  /// 实例
  static final BTDownloadTool instance = BTDownloadTool._();

  /// 默认 torrent 下载路径
  late String defaultPath;

  /// 是否初始化
  late bool isInit = false;

  /// 请求客户端
  final BTRequestClient client = BTRequestClient();

  /// 获取实例
  factory BTDownloadTool() => instance;

  /// 文件工具
  final BTFileTool fileTool = BTFileTool();

  /// 初始化
  Future<void> init() async {
    if (instance.isInit) return;
    instance.defaultPath = await instance.fileTool.getAppDataPath('download');
    var check = await instance.fileTool.isDirExist(instance.defaultPath);
    if (!check) {
      BTLogTool.info('Create default download dir');
      await instance.fileTool.createDir(instance.defaultPath);
    }
    instance.isInit = true;
    BTLogTool.info('BTDownloadTool init success');
  }

  /// 检测文件是否存在|是否为空
  Future<bool> checkFile(String saveDetailPath) async {
    var fileCheck = await instance.fileTool.isFileExist(saveDetailPath);
    if (!fileCheck) return false;
    var fileSize = instance.fileTool.getFileSize(saveDetailPath);
    if (fileSize == 0) {
      await instance.fileTool.deleteFile(saveDetailPath);
      return false;
    }
    return true;
  }

  /// 下载文件
  Future<String> downloadRssTorrent(
    String url,
    String title, {
    BuildContext? context,
  }) async {
    if (!instance.isInit) {
      await instance.init();
    }
    var link = Uri.parse(url);
    var fileName = path.basename(link.path);
    var saveDetailPath = path.join(instance.defaultPath, fileName);
    var fileCheck = await instance.checkFile(saveDetailPath);
    if (fileCheck) return saveDetailPath;
    var errInfo = ['', 'TorrentLink: $url', 'Title: $title'];
    try {
      await client.dio.download(url, saveDetailPath);
    } on DioException catch (e) {
      if (context != null && context.mounted) {
        var resp = BTResponse(
          code: e.response?.statusCode ?? 666,
          message: e.response?.statusMessage ?? '未知错误',
          data: e.error,
        );
        await showRespErr(resp, context);
      }
      errInfo[0] = 'DownloadTorrentErrorDio: \n\t${e.error}';
      BTLogTool.error(errInfo);
      return '';
    } on Exception catch (e) {
      if (context != null && context.mounted) {
        var resp = BTResponse(
          code: 666,
          message: e.toString(),
          data: null,
        );
        await showRespErr(resp, context);
      }
      errInfo[0] = 'DownloadTorrentError: \n\t${e.toString()}';
      BTLogTool.error(errInfo);
      return '';
    }
    fileCheck = await instance.checkFile(saveDetailPath);
    if (fileCheck) return saveDetailPath;
    if (context != null && context.mounted) {
      await BtInfobar.error(context, '下载失败，文件大小为0');
    }
    errInfo[0] = 'DownloadTorrentError: \n\t下载失败';
    BTLogTool.error(errInfo);
    return '';
  }
}
