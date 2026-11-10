// Dart imports:
import 'dart:async';
import 'dart:io';

// Project imports:
import '../../database/app/app_subscription.dart';
import '../cache/app_file_retention.dart';
import '../logging/log_tool.dart';
import 'file_service.dart';

/// Main-window maintenance. Shutdown drains accepted work before SQLite closes.
class AppDataRetentionService {
  AppDataRetentionService._();

  static final instance = AppDataRetentionService._();
  Timer? _timer;
  Future<void>? _flight;
  bool _stopped = false;

  Future<void> start() async {
    if (_stopped || _timer != null) return;
    _timer = Timer.periodic(
      const Duration(days: 1),
      (_) => unawaited(_maintain()),
    );
    await _maintain();
  }

  Future<void> _maintain() {
    if (_stopped) return Future.value();
    return _flight ??= _runMaintenance().whenComplete(() => _flight = null);
  }

  Future<void> _runMaintenance() async {
    const files = AppFileRetention();
    for (var task in <String, Future<void> Function()>{
      '迁移备份': () async => files.pruneBackups(
        Directory(await BTFileTool().getAppDataPath('app/backups')),
      ),
      'RSS 去重记录': () => appSubscriptionStorage.pruneKnownItems(),
      '剧集孤立记录': () => appSubscriptionStorage.pruneOrphanedPlaybackData(),
      'TensorRT 下载残留': () async =>
          files.pruneDownloads(Directory(await playbackTensorRtDirectory())),
    }.entries) {
      try {
        await task.value();
      } catch (error) {
        BTLogTool.warn('自动清理${task.key}失败：$error');
      }
    }
  }

  Future<void> stop() async {
    _stopped = true;
    _timer?.cancel();
    _timer = null;
    await _flight;
  }
}
