// Dart imports:
import 'dart:math';

// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../../core/theme/bt_theme.dart';
import '../../../models/bangumi/bangumi_enum.dart';
import '../../../models/bangumi/bangumi_model.dart';
import '../../../pages/subject-detail/subject_stat_providers.dart';
import '../../../providers/app_providers.dart';
import '../../../tools/log_tool.dart';
import 'bsd_episode.dart';

/// SubjectDetail页面的章节模块，负责显示/操作章节信息
class BsdUserEpisodes extends ConsumerStatefulWidget {
  /// subjectInfo
  final BangumiSubject subject;

  /// user
  final BangumiUser? user;

  /// provider
  final SubjectCollectStatProvider provider;

  /// 显示 m/n 进度摘要
  final bool showSummary;

  /// 是否直接展示剧集按钮格
  final bool showGrid;

  /// 构造函数
  const BsdUserEpisodes(
    this.subject,
    this.user,
    this.provider, {
    this.showSummary = false,
    this.showGrid = true,
    super.key,
  });

  @override
  ConsumerState<BsdUserEpisodes> createState() => _BsdUserEpisodesState();
}

// todo，当条目章节数量过多时，需要分页加载，比如名侦探柯南(id:899)
class _BsdUserEpisodesState extends ConsumerState<BsdUserEpisodes>
    with AutomaticKeepAliveClientMixin {
  /// subject_id
  int get subjectId => widget.subject.id;

  /// 用户
  BangumiUser? get user => widget.user;

  /// 是否收藏
  bool isCollection = false;

  VoidCallback? _removeProviderListener;
  bool _isRefreshing = false;

  /// 章节信息
  List<BangumiEpisode> episodes = [];

  /// 用户章节信息
  List<BangumiUserEpisodeCollection> userEpisodes = [];
  final Map<int, BangumiUserEpisodeCollection> _userEpById = {};

  /// offset
  int offset = 0;

  bool _gridExpanded = false;

  late bool _loading = widget.subject.type == BangumiSubjectType.anime;

  static const _pageSize = 100;

  Future<List<BangumiUserEpisodeCollection>?>? _userEpisodesInFlight;

  @override
  bool get wantKeepAlive => true;

  /// 初始化
  @override
  void initState() {
    super.initState();
    _gridExpanded = widget.showGrid;
    isCollection = widget.provider.collected;
    Future.microtask(() async {
      if (widget.subject.type == BangumiSubjectType.anime) {
        await load();
      }
    });
    _listenToProvider();
  }

  void _listenToProvider() {
    _removeProviderListener = widget.provider.addListener(_onProviderChanged);
  }

  void _onProviderChanged(bool value) async {
    if (user == null) return;
    if (widget.subject.type != BangumiSubjectType.anime) return;
    if (!value) {
      isCollection = false;
      if (userEpisodes.isNotEmpty) {
        userEpisodes.clear();
        _userEpById.clear();
        if (mounted) setState(() {});
      }
      return;
    }
    if (isCollection || _isRefreshing) return;
    isCollection = true;
    if (_loading) {
      _userEpisodesInFlight ??= _fetchUserEpisodePage(
        offset: 0,
        limit: _pageSize,
      );
      return;
    }
    _isRefreshing = true;
    try {
      await _loadUserEpisodes();
    } catch (error, stackTrace) {
      BTLogTool.error(['刷新章节信息失败', error.toString(), stackTrace.toString()]);
    } finally {
      _isRefreshing = false;
    }
  }

  Future<void> _loadUserEpisodes() async {
    if (user == null) return;
    var remaining = episodes.isEmpty ? _pageSize : episodes.length;
    var fetched = 0;
    while (fetched < remaining) {
      var limit = min(_pageSize, remaining - fetched);
      var page = await _fetchUserEpisodePage(offset: fetched, limit: limit);
      if (page == null || page.isEmpty) break;
      fetched += page.length;
      if (page.length < limit) break;
    }
    if (mounted) setState(() {});
  }

  Future<List<BangumiUserEpisodeCollection>?> _fetchUserEpisodePage({
    required int offset,
    required int limit,
  }) async {
    var resp = await ref
        .read(bangumiRepositoryProvider)
        .getCollectionEpisodes(subjectId, offset: offset, limit: limit);
    if (resp.code != 0 || resp.data == null) return null;
    _mergeUserEpisodes(resp.data!.data);
    return resp.data!.data;
  }

  void _mergeUserEpisodes(List<BangumiUserEpisodeCollection> items) {
    for (var item in items) {
      var index = userEpisodes.indexWhere(
        (e) => e.episode.id == item.episode.id,
      );
      if (index == -1) {
        userEpisodes.add(item);
      } else {
        userEpisodes[index] = item;
      }
      _userEpById[item.episode.id] = item;
    }
  }

  @override
  void didUpdateWidget(BsdUserEpisodes oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.provider, widget.provider)) {
      _removeProviderListener?.call();
      _listenToProvider();
    }
    if (oldWidget.showGrid != widget.showGrid) {
      _gridExpanded = widget.showGrid;
    }
  }

  @override
  void dispose() {
    _removeProviderListener?.call();
    super.dispose();
  }

  /// 加载更多
  Future<void> load() async {
    var isFirst = episodes.isEmpty;
    if (isFirst) _loading = true;
    var repository = ref.read(bangumiRepositoryProvider);
    isCollection = isCollection || widget.provider.collected;
    var epFuture = repository.getEpisodeList(
      subjectId,
      offset: offset,
      limit: _pageSize,
    );
    var userEpFuture = _userEpisodesInFlight;
    if (userEpFuture == null && user != null && isCollection) {
      userEpFuture = _fetchUserEpisodePage(offset: offset, limit: _pageSize);
      _userEpisodesInFlight = userEpFuture;
    }
    var ep1Resp = await epFuture;
    var pageLen = 0;
    if (ep1Resp.code == 0 && ep1Resp.data != null) {
      episodes.addAll(ep1Resp.data!.data);
      pageLen = ep1Resp.data!.data.length;
    }
    if (userEpFuture == null && user != null && widget.provider.collected) {
      isCollection = true;
      userEpFuture = _userEpisodesInFlight;
      userEpFuture ??= _fetchUserEpisodePage(offset: offset, limit: _pageSize);
      _userEpisodesInFlight = userEpFuture;
    }
    if (userEpFuture != null) {
      await userEpFuture;
    }
    _userEpisodesInFlight = null;
    offset += pageLen;
    if (isFirst) _loading = false;
    if (mounted) setState(() {});
  }

  /// buildEpHint 用于表示章节的提示信息
  Widget buildEpHint(BangumiEpType type) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        color: FluentTheme.of(context).accentColor,
      ),
      child: Text(
        '${type.label} →',
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
    );
  }

  /// buildList
  List<Widget> buildList() {
    var res = <Widget>[];
    var ordered = List<BangumiEpisode>.of(episodes)
      ..sort(
        (a, b) => a.type == b.type
            ? a.sort.compareTo(b.sort)
            : b.type.value.compareTo(a.type.value),
      );
    var curType = ordered[0].type;
    if (curType != BangumiEpType.main) {
      res.add(buildEpHint(curType));
    }
    for (var i = 0; i < ordered.length; i++) {
      if (curType != ordered[i].type) {
        curType = ordered[i].type;
        res.add(buildEpHint(curType));
      }
      var userEp = _userEpById[ordered[i].id];
      if (userEp != null) {
        res.add(BsdEpisode(ordered[i], user: userEp));
      } else {
        res.add(BsdEpisode(ordered[i]));
      }
    }
    if (episodes.length < widget.subject.totalEpisodes) {
      res.add(
        Button(
          onPressed: () async {
            await load();
          },
          child: const Text('加载更多'),
        ),
      );
    }
    return res;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (episodes.isEmpty) {
      if (_loading) {
        return const Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            key: ValueKey('subject-episodes-loading'),
            width: 24,
            height: 24,
            child: ProgressRing(strokeWidth: 2),
          ),
        );
      }
      if (!widget.showSummary) return const SizedBox.shrink();
      return Text('暂无剧集', style: BTTypography.caption(context));
    }
    var summary = widget.showSummary ? _buildSummary(context) : null;
    var showGridNow = widget.showGrid || _gridExpanded;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (summary != null) ...[summary, SizedBox(height: 8)],
        if (!showGridNow)
          Button(
            key: const ValueKey('subject-episodes-expand'),
            onPressed: () => setState(() => _gridExpanded = true),
            child: const Text('展开全部'),
          )
        else
          Wrap(spacing: 8, runSpacing: 8, children: buildList()),
      ],
    );
  }

  Widget _buildSummary(BuildContext context) {
    var mains = episodes.where((ep) => ep.type == BangumiEpType.main).toList();
    var done = 0;
    BangumiEpisode? next;
    for (var ep in mains) {
      var userEp = _userEpById[ep.id];
      var marked = userEp?.type == BangumiEpisodeCollectionType.done;
      if (marked) {
        done++;
      } else {
        next ??= ep;
      }
    }
    var total = mains.isNotEmpty ? mains.length : widget.subject.totalEpisodes;
    if (total <= 0) total = widget.subject.eps;
    var ratio = total <= 0 ? 0.0 : (done / total).clamp(0.0, 1.0);
    var nextLabel = '';
    if (next != null) {
      var name = next.nameCn.isEmpty ? next.name : next.nameCn;
      nextLabel = '下一话 EP${next.sort.toStringAsFixed(0)}';
      if (next.airDate.isNotEmpty) {
        nextLabel = '$nextLabel · ${next.airDate}';
      } else if (name.isNotEmpty) {
        nextLabel = '$nextLabel · $name';
      }
    }
    return Column(
      key: const ValueKey('subject-episodes-summary'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('正片 $done/$total', style: BTTypography.bodyStrong(context)),
        SizedBox(height: 6),
        SizedBox(height: 6, child: ProgressBar(value: ratio * 100)),
        if (nextLabel.isNotEmpty) ...[
          SizedBox(height: 6),
          Text(nextLabel, style: BTTypography.caption(context)),
        ],
      ],
    );
  }
}
