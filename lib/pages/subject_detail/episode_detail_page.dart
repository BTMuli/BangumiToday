// Dart imports:
import 'dart:async';

// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher_string.dart';

// Project imports:
import '../../core/theme/bt_theme.dart';
import '../../models/app/response.dart';
import '../../models/bangumi/bangumi_enum.dart';
import '../../models/bangumi/bangumi_model.dart';
import '../../providers/app_providers.dart';
import '../../request/bangumi/bangumi_api.dart';
import '../../ui/bt_dialog.dart';
import '../../widgets/common/bt_content_frame.dart';
import 'episode_detail_comments.dart';
import 'episode_detail_info.dart';
import 'subject_detail_colors.dart';

/// 从章节详情跳转到所属条目
typedef EpisodeSubjectJump = void Function(BangumiEpisodeSubject subject);

/// 相邻章节：用于剧集信息里的上一集 / 下一集切换
class EpisodeNeighbor {
  const EpisodeNeighbor({required this.id, required this.label});

  final int id;

  /// 形如 `ep.49 藷(いなご)`
  final String label;
}

/// 剧集详情
///
/// 作为条目详情的下一级页面展示：剧集信息固定在页头，
/// 下方是滚动的章节吐槽列表，返回后回到条目详情。
class EpisodeDetailPage extends ConsumerStatefulWidget {
  /// 章节 id
  final String id;

  /// 返回条目详情
  final VoidCallback onBack;

  /// 跳转到所属条目
  final EpisodeSubjectJump onOpenSubject;

  /// 切换到相邻章节
  final ValueChanged<int> onOpenEpisode;

  /// 构造函数
  const EpisodeDetailPage({
    super.key,
    required this.id,
    required this.onBack,
    required this.onOpenSubject,
    required this.onOpenEpisode,
  });

  /// 章节编号：整数不显示小数位，半话等保留一位。
  static String formatSort(double sort) {
    if (sort == sort.roundToDouble()) return sort.toStringAsFixed(0);
    return sort.toStringAsFixed(1);
  }

  @override
  ConsumerState<EpisodeDetailPage> createState() => _EpisodeDetailPageState();
}

/// 剧集详情状态
class _EpisodeDetailPageState extends ConsumerState<EpisodeDetailPage> {
  /// 章节详情
  BangumiEpisodeDetail? data;

  /// 是否显示错误组件
  bool showError = false;

  /// 刷新按钮进行中
  bool _refreshing = false;

  int _loadGeneration = 0;

  /// 评论列表的重载计数，连同页面刷新一起变化。
  int _commentsReloadToken = 0;

  /// 相邻章节，随剧集信息一起展示
  EpisodeNeighbor? _previous;
  EpisodeNeighbor? _next;

  /// 相邻章节最多翻这么多条，避免超长条目无限翻页
  static const int _neighborMaxEpisodes = 1000;

  static const int _neighborPageSize = 100;

  /// 网络层失败的响应码，见 AppError.fromResponse
  static const int _networkErrorCode = 666;

  /// 网络层失败的重试间隔：Next API 偶发握手中断，隔一会儿重试通常能成
  static const Duration _networkRetryDelay = Duration(milliseconds: 400);

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  @override
  void didUpdateWidget(EpisodeDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id) {
      Future.microtask(_load);
    }
  }

  @override
  void dispose() {
    _loadGeneration++;
    super.dispose();
  }

  /// 网络层失败（DNS / 代理 / 握手被中断）时重试一次，其余错误原样返回
  Future<BTResponse<T>> _withNetworkRetry<T>(
    Future<BTResponse<T>> Function() request,
  ) async {
    var response = await request();
    if (response.code != _networkErrorCode) return response;
    await Future<void>.delayed(_networkRetryDelay);
    if (!mounted) return response;
    return request();
  }

  /// 拉取章节详情
  Future<void> _load() async {
    var episode = int.tryParse(widget.id);
    if (episode == null) {
      setState(() => showError = true);
      return;
    }
    var generation = ++_loadGeneration;
    setState(() {
      data = null;
      showError = false;
      _previous = null;
      _next = null;
    });
    var repository = ref.read(bangumiRepositoryProvider);
    var response = await _withNetworkRetry(
      () => repository.getEpisodeDetail(episode),
    );
    if (!mounted || generation != _loadGeneration) return;
    if (response.code != 0 || response.data == null) {
      setState(() => showError = true);
      await showRespErr(response, context, title: '获取剧集详情失败');
      return;
    }
    setState(() => data = response.data);
    unawaited(_loadNeighbors(response.data!));
  }

  /// 拉取同类型的相邻章节，供上一集 / 下一集切换。
  ///
  /// 章节数超过一页时按 100 条翻页，直到拿到当前章节及其后一条。
  Future<void> _loadNeighbors(BangumiEpisodeDetail episode) async {
    var generation = _loadGeneration;
    var type = _legacyEpisodeType(episode.type);
    var repository = ref.read(bangumiRepositoryProvider);
    var episodes = <BangumiEpisode>[];
    var offset = 0;
    while (offset < _neighborMaxEpisodes) {
      var response = await _withNetworkRetry(
        () => repository.getEpisodeList(
          episode.subjectId,
          type: type,
          limit: _neighborPageSize,
          offset: offset,
        ),
      );
      if (!mounted || generation != _loadGeneration) return;
      var page = response.data;
      if (response.code != 0 || page == null) return;
      episodes.addAll(page.data);
      var found = episodes.indexWhere((item) => item.id == episode.id);
      var lastPage = page.data.length < _neighborPageSize;
      // 已拿到当前章节，并且拿到了它的下一条（或已经是最后一页）就结束
      if (found != -1 && (found + 1 < episodes.length || lastPage)) break;
      if (lastPage) break;
      offset += _neighborPageSize;
    }
    if (!mounted || generation != _loadGeneration) return;
    episodes.sort((a, b) => a.sort.compareTo(b.sort));
    var index = episodes.indexWhere((item) => item.id == episode.id);
    setState(() {
      _previous = index > 0 ? _neighbor(episodes[index - 1]) : null;
      _next = index != -1 && index + 1 < episodes.length
          ? _neighbor(episodes[index + 1])
          : null;
    });
  }

  EpisodeNeighbor _neighbor(BangumiEpisode episode) => EpisodeNeighbor(
    id: episode.id,
    label: _episodeLabel(episode.nameCn, episode.name, episode.sort),
  );

  /// 章节类型与章节列表接口的枚举值一致
  BangumiLegacyEpisodeType _legacyEpisodeType(BangumiEpType type) {
    for (var item in BangumiLegacyEpisodeType.values) {
      if (item.value == type.value) return item;
    }
    return BangumiLegacyEpisodeType.main;
  }

  /// 刷新页面：重新拉取章节详情与吐槽列表。
  Future<void> refresh() async {
    var episode = int.tryParse(widget.id);
    if (!mounted || _refreshing || episode == null) return;
    var generation = _loadGeneration;
    setState(() => _refreshing = true);
    try {
      var repository = ref.read(bangumiRepositoryProvider);
      var response = await _withNetworkRetry(
        () => repository.getEpisodeDetail(episode),
      );
      if (!mounted || generation != _loadGeneration) return;
      if (response.code != 0 || response.data == null) {
        await showRespErr(response, context, title: '获取剧集详情失败');
        return;
      }
      setState(() {
        data = response.data;
        _commentsReloadToken++;
      });
      unawaited(_loadNeighbors(response.data!));
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldPage(
      header: buildHeader(),
      content: Stack(
        fit: StackFit.expand,
        children: [
          BTContentFrame(maxWidth: 1440, child: buildContent()),
          // 手动刷新不会卸载内容树，用顶部进度条显示刷新过程。
          if (_refreshing)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: IgnorePointer(child: ProgressBar(strokeWidth: 3)),
            ),
        ],
      ),
    );
  }

  /// 构建页头：返回、标题与剧集信息
  Widget buildHeader() {
    var padding = PageHeader.horizontalPadding(context);
    var episode = data;
    return Padding(
      padding: EdgeInsetsDirectional.only(bottom: 8, end: padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          buildTopBar(),
          if (episode != null) ...[
            const SizedBox(height: 4),
            Padding(
              padding: EdgeInsetsDirectional.only(start: padding),
              // 简介与信息在封面右侧同一处滚动，卡片整体不超过页头高度
              child: EpisodeDetailOverview(
                data: episode,
                maxHeight: MediaQuery.sizeOf(context).height * 0.4,
                onOpenSubject: widget.onOpenSubject,
                onOpenEpisode: widget.onOpenEpisode,
                previous: _previous,
                next: _next,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 构建页头第一行
  Widget buildTopBar() {
    var theme = FluentTheme.of(context);
    return Row(
      children: [
        IconButton(
          icon: const Icon(FluentIcons.back),
          onPressed: widget.onBack,
        ),
        Expanded(
          child: DefaultTextStyle.merge(
            style: theme.typography.subtitle,
            child: const Text('剧集详情', overflow: TextOverflow.ellipsis),
          ),
        ),
        SizedBox(width: PageHeader.horizontalPadding(context)),
        Tooltip(
          message: '在浏览器中打开章节页面',
          child: IconButton(
            icon: const Icon(FluentIcons.link, size: 16),
            onPressed: () => unawaited(
              launchUrlString('${BtrBangumiApi.siteBaseUrl}/ep/${widget.id}'),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Tooltip(
          message: _refreshing ? '正在刷新' : '刷新页面',
          child: IconButton(
            icon: _refreshing
                ? const SizedBox.square(
                    dimension: 16,
                    child: ProgressRing(strokeWidth: 2),
                  )
                : const Icon(FluentIcons.refresh, size: 16),
            onPressed: _refreshing ? null : refresh,
          ),
        ),
      ],
    );
  }

  /// 构建加载中或加载失败
  Widget buildLoading() {
    if (showError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(FluentIcons.error),
            const SizedBox(height: 12),
            const Text('Error: 加载失败'),
            const SizedBox(height: 12),
            Tooltip(
              message: '重新加载章节详情',
              child: Button(onPressed: _load, child: const Text('重试')),
            ),
          ],
        ),
      );
    }
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const ProgressRing(),
          const SizedBox(height: 12),
          const Text('Loading...'),
        ],
      ),
    );
  }

  /// 构建正文：吐槽列表
  Widget buildContent() {
    var episode = data;
    if (episode == null) return buildLoading();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: SubjectDetailColors.content(context),
          borderRadius: BTRadius.mediumBR,
          border: Border.all(color: BTColors.divider(context)),
        ),
        child: EpisodeDetailComments(
          episodeId: episode.id,
          total: episode.comment,
          reloadToken: _commentsReloadToken,
        ),
      ),
    );
  }
}

/// 章节标题，形如 `ep.49 藷(いなご)`，名称为空时只留编号。
String _episodeLabel(String nameCn, String name, double sort) {
  var number = 'ep.${EpisodeDetailPage.formatSort(sort)}';
  var title = nameCn.trim().isEmpty ? name.trim() : nameCn.trim();
  return title.isEmpty ? number : '$number $title';
}
