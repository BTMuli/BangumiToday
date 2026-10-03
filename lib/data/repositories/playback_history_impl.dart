// Project imports:
import '../../database/app/app_playback.dart';
import '../../domain/repositories/playback_history.dart';
import '../../models/playback/playback_item.dart';

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
