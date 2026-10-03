// Project imports:
import '../../database/app/app_playback.dart';
import '../../models/playback/playback_item.dart';

/// 播放历史存储接口。
///
/// 独立播放窗口等场景可以替换实现，播放会话只依赖该契约，不直接持有表访问器。
abstract class PlaybackHistoryStore {
  Future<PlaybackItem?> read(String filePath);

  Future<List<PlaybackItem>> readAll();

  Future<void> write(PlaybackItem item);

  Future<void> delete(String filePath);
}

/// 现有 SQLite（AppPlayback 表）实现。
class AppPlaybackHistoryStore implements PlaybackHistoryStore {
  AppPlaybackHistoryStore({BtsAppPlayback? table})
    : _table = table ?? BtsAppPlayback();

  final BtsAppPlayback _table;

  @override
  Future<PlaybackItem?> read(String filePath) => _table.read(filePath);

  @override
  Future<List<PlaybackItem>> readAll() => _table.readAll();

  @override
  Future<void> write(PlaybackItem item) => _table.write(item);

  @override
  Future<void> delete(String filePath) => _table.delete(filePath);
}
