// Dart imports:
import 'dart:math';

// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../core/theme/bt_theme.dart';
import '../../models/bangumi/bangumi_enum.dart';
import '../../models/bangumi/bangumi_model.dart';
import '../../providers/app_providers.dart';
import '../../providers/episode_mark_providers.dart';
import '../../tools/log_tool.dart';
import '../../ui/bt_dialog.dart';
import 'subject_detail_refreshable.dart';
import 'subject_episode.dart';
import 'subject_episode_load_queue.dart';
import 'subject_stat_providers.dart';

/// SubjectDetail页面的章节模块，负责显示/操作章节信息
class SubjectUserEpisodes extends ConsumerStatefulWidget {
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
  const SubjectUserEpisodes(
    this.subject,
    this.user,
    this.provider, {
    this.showSummary = false,
    this.showGrid = true,
    super.key,
  });

  @override
  ConsumerState<SubjectUserEpisodes> createState() =>
      _SubjectUserEpisodesState();
}

// todo，当条目章节数量过多时，需要分页加载，比如名侦探柯南(id:899)
class _SubjectUserEpisodesState extends ConsumerState<SubjectUserEpisodes>
    with AutomaticKeepAliveClientMixin, SubjectDetailRefreshable {
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

  /// 章节列表加载失败的原因，null 表示没有失败
  String? _loadError;

  bool _gridExpanded = false;

  late bool _loading = widget.subject.type == BangumiSubjectType.anime;

  static const _pageSize = 100;

  Future<List<BangumiUserEpisodeCollection>?>? _userEpisodesInFlight;

  late final _loads = SubjectEpisodeLoadQueue(
    loadPage: (reportError) => _loadPage(reportError: reportError),
    refreshList: _refreshEpisodes,
  );

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
        await load(reportError: true);
      }
    });
    _listenToProvider();
  }

  void _listenToProvider() {
    _removeProviderListener = widget.provider.listen(_onProviderChanged);
  }

  void _onProviderChanged() async {
    var value = widget.provider.collected;
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

  /// 重新拉取章节列表与用户章节状态（由详情页刷新按钮触发）
  @override
  Future<void> refresh() => _loads.refresh();

  Future<void> _refreshEpisodes() async {
    if (!mounted) return;
    if (widget.subject.type != BangumiSubjectType.anime) return;
    var episodeBackup = List<BangumiEpisode>.of(episodes);
    var userEpisodeBackup = List<BangumiUserEpisodeCollection>.of(userEpisodes);
    var userEpMapBackup = Map<int, BangumiUserEpisodeCollection>.of(
      _userEpById,
    );
    var offsetBackup = offset;
    episodes.clear();
    userEpisodes.clear();
    _userEpById.clear();
    _userEpisodesInFlight = null;
    offset = 0;
    try {
      await _loadPage(reportError: true);
    } finally {
      // 接口失败（如 502）时保留刷新前的章节，避免整块被清空。
      if (mounted && episodes.isEmpty && episodeBackup.isNotEmpty) {
        episodes = episodeBackup;
        userEpisodes = userEpisodeBackup;
        _userEpById
          ..clear()
          ..addAll(userEpMapBackup);
        offset = offsetBackup;
        setState(() {});
      }
    }
  }

  Future<List<BangumiUserEpisodeCollection>?> _fetchUserEpisodePage({
    required int offset,
    required int limit,
    bool reportError = false,
  }) async {
    if (!mounted) return null;
    var marking = ref.read(episodeMarkProvider.notifier);
    var account = marking.currentAccount();
    var progressVersion = marking.progressVersion;
    var resp = await ref
        .read(bangumiRepositoryProvider)
        .getCollectionEpisodes(subjectId, offset: offset, limit: limit);
    if (!mounted) return null;
    if (resp.code != 0 || resp.data == null) {
      if (reportError && mounted) {
        await showRespErr(resp, context, title: '获取章节进度失败');
      }
      return null;
    }
    marking.receiveSubjectProgress(
      subjectId,
      resp.data!.data,
      account: account,
      since: progressVersion,
    );
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
  void didUpdateWidget(SubjectUserEpisodes oldWidget) {
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
  ///
  /// [reportError] 用于区分「用户明确要数据」（首次挂载、点刷新、加载更多）
  /// 与后台状态同步：前者失败要弹提示，后者保持静默。
  Future<void> load({bool reportError = false}) =>
      _loads.load(reportError: reportError);

  Future<void> _loadPage({bool reportError = false}) async {
    if (!mounted) return;
    var isFirst = episodes.isEmpty;
    if (isFirst) _loading = true;
    var pageOffset = offset;
    var repository = ref.read(bangumiRepositoryProvider);
    isCollection = isCollection || widget.provider.collected;
    var epFuture = repository.getEpisodeList(
      subjectId,
      offset: pageOffset,
      limit: _pageSize,
    );
    var userEpFuture = _userEpisodesInFlight;
    if (userEpFuture == null && user != null && isCollection) {
      userEpFuture = _fetchUserEpisodePage(
        offset: pageOffset,
        limit: _pageSize,
        reportError: reportError,
      );
      _userEpisodesInFlight = userEpFuture;
    }
    var ep1Resp = await epFuture;
    if (!mounted) return;
    var pageLen = 0;
    if (ep1Resp.code == 0 && ep1Resp.data != null) {
      // Pagination boundaries may overlap; a chapter ID is rendered once.
      episodes = {
        for (var episode in episodes) episode.id: episode,
        for (var episode in ep1Resp.data!.data) episode.id: episode,
      }.values.toList();
      pageLen = ep1Resp.data!.data.length;
      _loadError = null;
    } else {
      _loadError = ep1Resp.message;
      // 先把内联错误态渲染出来（含结束 loading），再弹窗，
      // 否则提示要等弹窗关闭后才出现。
      if (isFirst) _loading = false;
      if (mounted) setState(() {});
      if (reportError && mounted) {
        await showRespErr(ep1Resp, context, title: '获取章节列表失败');
      }
    }
    if (userEpFuture == null && user != null && widget.provider.collected) {
      isCollection = true;
      userEpFuture = _userEpisodesInFlight;
      userEpFuture ??= _fetchUserEpisodePage(
        offset: pageOffset,
        limit: _pageSize,
        reportError: reportError,
      );
      _userEpisodesInFlight = userEpFuture;
    }
    if (userEpFuture != null) {
      await userEpFuture;
    }
    _userEpisodesInFlight = null;
    offset = pageOffset + pageLen;
    if (isFirst) _loading = false;
    if (mounted) setState(() {});
  }

  /// 加载失败：左侧刷新按钮 + 异常描述
  Widget _buildLoadError(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Row(
        key: const ValueKey('subject-episodes-error'),
        mainAxisSize: MainAxisSize.min,
        children: [
          Tooltip(
            message: '重新加载剧集',
            child: IconButton(
              icon: const Icon(FluentIcons.refresh, size: 14),
              onPressed: () async {
                await load(reportError: true);
              },
            ),
          ),
          SizedBox(width: 4),
          Flexible(
            child: Text(
              '剧集加载失败：$_loadError',
              style: BTTypography.caption(context),
            ),
          ),
        ],
      ),
    );
  }

  /// 每种章节类型独立渲染标题与按钮格，正片优先。
  List<Widget> _buildGroups(BuildContext context) {
    var res = <Widget>[];
    var groups = <BangumiEpType, List<BangumiEpisode>>{};
    for (var episode in episodes) {
      groups.putIfAbsent(episode.type, () => []).add(episode);
    }
    for (var type in BangumiEpType.values) {
      var group = groups[type];
      if (group == null) continue;
      group.sort((a, b) => a.sort.compareTo(b.sort));
      res.add(
        Padding(
          key: ValueKey('subject-episode-group-${type.name}'),
          padding: const EdgeInsets.only(bottom: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSummary(context, type, group),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var episode in group)
                    SubjectEpisode(
                      episode,
                      subject: subjectId,
                      user: _userEpById[episode.id],
                      key: ValueKey(episode.id),
                    ),
                ],
              ),
            ],
          ),
        ),
      );
    }
    if (episodes.length < widget.subject.totalEpisodes) {
      res.add(
        Button(
          onPressed: () async {
            await load(reportError: true);
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
      if (_loadError != null) return _buildLoadError(context);
      if (!widget.showSummary) return const SizedBox.shrink();
      return Text('暂无剧集', style: BTTypography.caption(context));
    }
    var showGridNow = widget.showGrid || _gridExpanded;
    var mains = episodes.where((ep) => ep.type == BangumiEpType.main).toList()
      ..sort((a, b) => a.sort.compareTo(b.sort));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!showGridNow && widget.showSummary && mains.isNotEmpty) ...[
          _buildSummary(context, BangumiEpType.main, mains),
          const SizedBox(height: 8),
        ],
        if (!showGridNow)
          Button(
            key: const ValueKey('subject-episodes-expand'),
            onPressed: () => setState(() => _gridExpanded = true),
            child: const Text('展开全部'),
          )
        else
          ..._buildGroups(context),
      ],
    );
  }

  Widget _buildSummary(
    BuildContext context,
    BangumiEpType type,
    List<BangumiEpisode> group,
  ) {
    var label = type == BangumiEpType.main ? '正片' : type.label;
    if (!widget.showSummary) {
      return Text(
        '$label · ${group.length} 集',
        style: BTTypography.bodyStrong(context),
      );
    }
    var done = 0;
    BangumiEpisode? next;
    for (var ep in group) {
      var userEp = _userEpById[ep.id];
      var marked = userEp?.type == BangumiEpisodeCollectionType.done;
      if (marked) {
        done++;
      } else {
        next ??= ep;
      }
    }
    var total = group.length;
    var ratio = total <= 0 ? 0.0 : (done / total).clamp(0.0, 1.0);
    var nextLabel = '';
    if (next != null && type == BangumiEpType.main) {
      var name = next.nameCn.isEmpty ? next.name : next.nameCn;
      nextLabel = '下一话 EP${next.sort.toStringAsFixed(0)}';
      if (next.airDate.isNotEmpty) {
        nextLabel = '$nextLabel · ${next.airDate}';
      } else if (name.isNotEmpty) {
        nextLabel = '$nextLabel · $name';
      }
    }
    return Column(
      key: ValueKey('subject-episodes-summary-${type.name}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label $done/$total', style: BTTypography.bodyStrong(context)),
        if (type == BangumiEpType.main) ...[
          const SizedBox(height: 6),
          SizedBox(height: 6, child: ProgressBar(value: ratio * 100)),
        ],
        if (nextLabel.isNotEmpty) ...[
          SizedBox(height: 6),
          Text(nextLabel, style: BTTypography.caption(context)),
        ],
      ],
    );
  }
}
