// Project imports:
import '../../core/errors/playback_unavailable.dart';
import '../../models/playback/playback_item.dart';

/// 本地视频资源的就绪校验与播放列表发现接口。
///
/// 播放会话只依赖该契约：主窗口注入基于下载引擎快照的本地实现，独立播放
/// 窗口等场景注入通信适配器，两侧遵循同一套“未完成下载不算就绪”的语义。
abstract class PlaybackLibrary {
  /// 校验单个文件是否可以播放，不满足时抛出 [PlaybackUnavailable]。
  Future<void> ensureReady(String filePath);

  /// 扫描目录下的可播放文件，优先按季号、集数排序，同集按文件名自然排序。
  Future<List<PlaybackItem>> discover(String dir, {int? subject});
}
