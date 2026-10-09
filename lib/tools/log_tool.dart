// Dart imports:
import 'dart:io';

// Flutter imports:
import 'package:flutter/foundation.dart';

// Package imports:
import 'package:logger/logger.dart';

// Project imports:
import '../core/services/file_service.dart';
import 'durable_log_output.dart';
import 'log_identity.dart';

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
  static final _pending = <({Level level, String message})>[];

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

  /// 初始化
  static Future<void> init({String scope = 'main'}) async {
    if (_isInitialized) return;
    logDir = await instance.fileTool.getAppDataPath('log');
    await Directory(logDir).create(recursive: true);
    var safeScope = scope.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    logger = Logger(
      filter: BTLogFilter(),
      level: Level.all,
      output: MultiOutput([
        ConsoleOutput(),
        BTDurableLogOutput(
          logDir,
          safeScope,
          onError: (error) => debugPrint(sanitize('日志文件操作失败：$error')),
        ),
      ]),
      printer: PrettyPrinter(
        methodCount: kDebugMode ? 5 : 0,
        errorMethodCount: 5,
        lineLength: 100,
        colors: false,
        printEmojis: true,
        dateTimeFormat: DateTimeFormat.dateAndTime,
      ),
    );
    _isInitialized = true;
    for (var entry in _pending) {
      logger.log(entry.level, entry.message);
    }
    _pending.clear();
    info(
      '日志已初始化：scope=$safeScope，pid=$pid，'
      'session=${BTLogIdentity.current.session}',
    );
  }

  /// 打开日志目录
  Future<void> openLogDir() async {
    var dir = await instance.fileTool.getAppDataPath('log');
    await fileTool.openDir(dir);
  }

  /// 打印信息日志
  static void info(dynamic message) {
    _log(Level.info, message);
  }

  /// 打印警告日志
  static void warn(dynamic message) {
    _log(Level.warning, message);
  }

  /// 打印错误日志
  static void error(dynamic message) {
    _log(Level.error, message);
  }

  static void _log(Level level, dynamic message) {
    var str = sanitize(message);
    if (!_isInitialized) {
      if (_pending.length == 100) _pending.removeAt(0);
      _pending.add((level: level, message: str));
      debugPrint(str);
      return;
    }
    logger.log(level, str);
  }
}
