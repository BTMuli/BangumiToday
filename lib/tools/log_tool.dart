import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart' as path;

import 'file_tool.dart';

/// 日志工具
class BTLogTool {
  BTLogTool._();

  /// 实例
  static final BTLogTool _instance = BTLogTool._();

  /// 日志
  late Logger _logger;

  /// 获取实例
  factory BTLogTool() => _instance;

  /// 文件工具
  final BTFileTool _fileTool = BTFileTool();

  /// 获取日志目录
  Future<String> _getDefaultDir() async {
    var dir = await _instance._fileTool.getAppDataDir();
    return path.join('$dir', 'log');
  }

  /// 获取文件名称 yyyy-MM-dd.log
  static String _getFileName() {
    var now = DateTime.now();
    return '${now.year}-${now.month}-${now.day}.log';
  }

  /// 获取日志文件
  Future<File> _getLogFile() async {
    var dir = await _getDefaultDir();
    var file = path.join('$dir', _getFileName());
    if (!await _instance._fileTool.isFileExist(file)) {
      await _instance._fileTool.createFile(file);
    }
    return File(file);
  }

  /// 初始化
  Future<void> init() async {
    var outputC = ConsoleOutput();
    var outputs = <LogOutput>[outputC];
    var printer;
    if (!kDebugMode) {
      var outputF = FileOutput(file: await _getLogFile());
      outputs.add(outputF);
      printer = PrettyPrinter(
        methodCount: 0,
        errorMethodCount: 5,
        lineLength: 100,
        colors: false,
        printEmojis: true,
        printTime: true,
      );
    } else {
      printer = PrettyPrinter(printTime: true);
    }
    _logger = Logger(
      level: Level.all,
      output: MultiOutput(outputs),
      printer: printer,
    );
    info('BTLogTool init');
  }

  /// 打印调试日志
  static void debug(dynamic message) {
    _instance._logger.log(Level.debug, message);
  }

  /// 打印信息日志
  static void info(dynamic message) {
    _instance._logger.log(Level.info, message);
  }

  /// 打印警告日志
  static void warn(dynamic message) {
    _instance._logger.log(Level.warning, message);
  }

  /// 打印错误日志
  static void error(dynamic message) {
    _instance._logger.log(Level.error, message);
  }
}
