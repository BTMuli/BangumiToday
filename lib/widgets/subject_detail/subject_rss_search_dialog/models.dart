part of '../subject_rss_search_dialog.dart';

enum _RssSearchSource { mikan, anibt }

/// AppConfig 键：记住上次 RSS 搜索来源（`anibt` / `mikan`）。
const _rssSearchSourceConfigKey = 'rssSearchSource';

/// 会话内回退：AppConfig 异步读出前，或读写失败时沿用本次进程内上次选择。
_RssSearchSource? _sessionRssSearchSource;

_RssSearchSource _parseRssSearchSource(String? value) {
  if (value == 'mikan') return _RssSearchSource.mikan;
  if (value == 'anibt') return _RssSearchSource.anibt;
  return _sessionRssSearchSource ?? _RssSearchSource.anibt;
}

class _RssSearchSelection {
  final _RssSearchSource source;
  final String animeId;
  final String title;
  final String rss;
  final String? groupId;
  final String? groupName;

  const _RssSearchSelection({
    required this.source,
    required this.animeId,
    required this.title,
    required this.rss,
    this.groupId,
    this.groupName,
  });

  String get label => groupName == null ? title : '$title / $groupName';

  bool matches(_RssSearchSource source, String animeId) =>
      this.source == source && this.animeId == animeId;

  _RssSearchSelection withGroupName(String name) => _RssSearchSelection(
    source: source,
    animeId: animeId,
    title: title,
    rss: rss,
    groupId: groupId,
    groupName: name,
  );
}

/// 条目字幕组的加载状态；展开条目时按需加载并缓存。
class _AnibtGroupsState {
  List<AnibtAnimeGroup> groups = const [];
  bool loading = false;
  bool loaded = false;
  String? error;
}

/// 蜜柑番剧详情的加载状态；展开条目时按需加载并缓存。
class _MikanDetailState {
  MikanBangumiDetailModel? detail;
  bool loading = false;
  bool loaded = false;
  String? error;
}
