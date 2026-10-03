// Project imports:
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
