// Project imports:
import 'playback_item.dart';

/// The account's chapter progress, separate from local playback completion.
class EpisodeMarkState {
  const EpisodeMarkState({
    this.account,
    this.marked = const {},
    this.checked = const {},
    this.loading = const {},
  });

  final String? account;
  final Set<String> marked;
  final Set<String> checked;
  final Set<String> loading;

  String? autoMarkDisabledReason(PlaybackItem? item) {
    if (item == null) return '请先播放视频';
    if (account == null) return '请先登录 Bangumi';
    if ((item.subject ?? 0) <= 0) return '当前文件未关联番剧';
    var key = itemKey(item);
    if (loading.contains(key)) return '正在读取条目观看进度…';
    if (!checked.contains(key)) return '当前文件尚未唯一匹配章节并确认观看进度';
    return null;
  }

  static String itemKey(PlaybackItem item) => '${item.subject}:${item.key}';
}
