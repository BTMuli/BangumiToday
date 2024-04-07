import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart' as path;

import 'file_tool.dart';

/// 日志工具
class BTLogTool {
  BTLogTool._();

  static late Logger _logger;

  /// 获取日志目录
  static Future<String> _getDefaultDir() async {
    var dir = await BTFileTool.getAppDataDir();
    return path.join('$dir', 'app', 'log');
  }

  /// 获取文件名称 yyyy-MM-dd.log
  static String _getFileName() {
    var now = DateTime.now();
    return '${now.year}-${now.month}-${now.day}.log';
  }

  /// 获取日志文件
  /// todo 更改目录
  static Future<File> _getLogFile() async {
    var dir = await _getDefaultDir();
    var file = path.join('$dir', _getFileName());
    if (!await BTFileTool.isFileExist(file)) {
      await BTFileTool.createFile(file);
    }
    return File(file);
  }

  /// 初始化
  static Future<void> init() async {
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
    _logger.log(Level.debug, message);
  }

  /// 打印信息日志
  static void info(dynamic message) {
    _logger.log(Level.info, message);
  }

  /// 打印警告日志
  static void warn(dynamic message) {
    _logger.log(Level.warning, message);
  }

  /// 打印错误日志
  static void error(dynamic message) {
    _logger.log(Level.error, message);
  }
}
