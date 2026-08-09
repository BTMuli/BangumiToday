// Dart imports:
import 'dart:io';

// Flutter imports:
import 'package:flutter/foundation.dart';

// Package imports:
import 'package:logger/logger.dart';
import 'package:path/path.dart' as path;

// Project imports:
import 'file_tool.dart';

/// 因为Release模式下，日志文件是限制的
/// 详见：https://github.com/SourceHorizon/logger?tab=readme-ov-file#logfilter
/// 因此需要自己写一个LogFilter
class BTLogFilter extends LogFilter {
  @override
  bool shouldLog(LogEvent event) {
    if (kDebugMode) return true;
    return event.level.index > Level.debug.index;
  }
}

/// 日志工具
class BTLogTool {
  BTLogTool._();

  /// 实例
  static final BTLogTool instance = BTLogTool._();

  /// 日志
  static late Logger logger;

  static bool _isInitialized = false;

  /// 日志工具是否已完成初始化
  static bool get isInitialized => _isInitialized;

  /// 日志目录
  static late String logDir;

  /// 删除日志、异常和网络 URL 中可能包含的凭据。
  static String sanitize(Object? message) {
    var value = message?.toString() ?? '';
    if (message is List<String>) value = message.join('\n');

    value = value.replaceAllMapped(
      RegExp(
        r'(authorization\s*[:=]\s*bearer\s+)[^\s,}]+',
        caseSensitive: false,
      ),
      (match) => '${match.group(1)}[REDACTED]',
    );
    value = value.replaceAllMapped(
      RegExp(
        r'([?&](?:token|code|access_token|refresh_token|client_secret)\s*=)[^&#\s}]+',
        caseSensitive: false,
      ),
      (match) => '${match.group(1)}[REDACTED]',
    );
    value = value.replaceAllMapped(
      RegExp(
        r'''(["']?(?:token|access_token|refresh_token|client_secret|app_secret|authorization)["']?\s*[:=]\s*["']?)[^"'\s,}]+''',
        caseSensitive: false,
      ),
      (match) => '${match.group(1)}[REDACTED]',
    );
    return value;
  }

  /// 获取实例
  factory BTLogTool() => instance;

  /// 文件工具
  final BTFileTool fileTool = BTFileTool();

  /// 获取文件名称 yyyy-MM-dd.log
  static String _getFileName() {
    var now = DateTime.now();
    return '${now.year}-${now.month}-${now.day}.log';
  }

  /// 获取日志文件
  static Future<File> _getLogFile() async {
    var file = path.join(logDir, _getFileName());
    if (!await instance.fileTool.isFileExist(file)) {
      return await instance.fileTool.createFile(file);
    }
    return File(file);
  }

  /// 初始化
  static Future<void> init() async {
    logDir = await instance.fileTool.getAppDataPath('log');
    var outputC = ConsoleOutput();
    var outputs = <LogOutput>[outputC];
    PrettyPrinter printer;
    if (!kDebugMode) {
      var file = await _getLogFile();
      var outputF = FileOutput(file: file, overrideExisting: false);
      outputs.add(outputF);
      printer = PrettyPrinter(
        methodCount: 0,
        errorMethodCount: 5,
        lineLength: 100,
        colors: false,
        printEmojis: true,
        dateTimeFormat: DateTimeFormat.dateAndTime,
      );
    } else {
      printer = PrettyPrinter(
        dateTimeFormat: DateTimeFormat.dateAndTime,
        methodCount: 5,
      );
    }
    logger = Logger(
      filter: BTLogFilter(),
      level: Level.all,
      output: MultiOutput(outputs),
      printer: printer,
    );
    _isInitialized = true;
  }

  /// 打开日志目录
  Future<void> openLogDir() async {
    var dir = await instance.fileTool.getAppDataPath('log');
    await fileTool.openDir(dir);
  }

  /// 打印信息日志
  static void info(dynamic message) {
    var str = sanitize(message);
    if (!_isInitialized) {
      debugPrint(str);
      return;
    }
    logger.log(Level.info, str);
  }

  /// 打印警告日志
  static void warn(dynamic message) {
    var str = sanitize(message);
    if (!_isInitialized) {
      debugPrint(str);
      return;
    }
    logger.log(Level.warning, str);
  }

  /// 打印错误日志
  static void error(dynamic message) {
    var str = sanitize(message);
    if (!_isInitialized) {
      debugPrint(str);
      return;
    }
    logger.log(Level.error, str);
  }
}
