import '../database/app/app_config.dart';

/// 下载任务累计耗时的持久化存储，跨 App 重启保留。
abstract interface class BtTaskElapsedStore {
  Future<int?> readSeconds(String taskId);

  Future<void> writeSeconds(String taskId, int seconds);

  Future<void> delete(String taskId);
}

/// 基于应用 SQLite 配置表的实现。
class BtSqliteTaskElapsedStore implements BtTaskElapsedStore {
  const BtSqliteTaskElapsedStore();

  static const _keyPrefix = 'btTaskElapsed:';

  @override
  Future<int?> readSeconds(String taskId) async {
    var value = await BtsAppConfig().read('$_keyPrefix$taskId');
    if (value == null || value.isEmpty) return null;
    return int.tryParse(value);
  }

  @override
  Future<void> writeSeconds(String taskId, int seconds) async {
    if (seconds <= 0) return;
    await BtsAppConfig().write('$_keyPrefix$taskId', '$seconds');
  }

  @override
  Future<void> delete(String taskId) async {
    await BtsAppConfig().delete('$_keyPrefix$taskId');
  }
}
