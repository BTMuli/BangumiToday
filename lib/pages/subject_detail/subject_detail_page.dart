// Dart imports:
import 'dart:async';

// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../models/bangumi/bangumi_enum.dart';
import '../../models/bangumi/bangumi_model.dart';
import '../../models/database/app_bmf_model.dart';
import '../../models/hive/nav_model.dart';
import '../../providers/app_providers.dart';
import '../../providers/episode_mark_providers.dart';
import '../../tools/log_tool.dart';
import '../../ui/bt_dialog.dart';
import '../../ui/bt_infobar.dart';
import '../../widgets/common/bt_content_frame.dart';
import '../../widgets/subject_detail/subject_rss_search_dialog.dart';
import '../subject_search/subject_search_page.dart';
import 'episode_detail_page.dart';
import 'subject_detail_layout.dart';
import 'subject_detail_prefetch.dart';
import 'subject_detail_refreshable.dart';
import 'subject_detail_resources.dart';
import 'subject_detail_view_data.dart';
import 'subject_stat_providers.dart';

part 'subject_detail_page/header.dart';
part 'subject_detail_page/content.dart';
part 'subject_detail_page/context_menu.dart';

/// 番剧详情
class SubjectDetailPage extends ConsumerStatefulWidget {
  /// 番剧 id
  final String id;

  /// 构造函数
  const SubjectDetailPage({super.key, required this.id});

  @override
  ConsumerState<SubjectDetailPage> createState() => _SubjectDetailPageState();
}

/// 番剧详情状态
class _SubjectDetailPageState extends ConsumerState<SubjectDetailPage>
    with AutomaticKeepAliveClientMixin {
  /// 番剧数据
  BangumiSubject? data;

  /// collect provider
  final SubjectCollectStatProvider collectProvider =
      SubjectCollectStatProvider();

  /// rss provider
  final SubjectRssStatProvider rssProvider = SubjectRssStatProvider();

  @override
  bool get wantKeepAlive => true;

  /// 是否显示错误组件
  bool showError = false;

  /// 刷新按钮进行中
  bool _refreshing = false;

  /// 当前展开的章节详情，null 表示停留在条目详情。
  String? _episodeId;

  int _loadGeneration = 0;
  SubjectDetailPrefetch? _prefetch;
  final GlobalKey _collectionKey = GlobalKey();
  final GlobalKey _episodesKey = GlobalKey();
  final GlobalKey _relationsKey = GlobalKey();
  final GlobalKey _charactersKey = GlobalKey();
  final GlobalKey _personsKey = GlobalKey();
  final GlobalKey _commentsKey = GlobalKey();
  final GlobalKey _resourcesKey = GlobalKey();

  /// 当id改变时, 重新加载数据
  @override
  void didUpdateWidget(SubjectDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id) {
      data = null;
      Future.microtask(init);
    }
  }

  /// 构建函数
  @override
  void initState() {
    super.initState();
    Future.microtask(init);
  }

  Future<void> init() async {
    if (!mounted) return;
    var generation = ++_loadGeneration;
    _prefetch = null;
    collectProvider.set(false);
    setState(() {
      showError = false;
      data = null;
    });
    var repository = ref.read(bangumiRepositoryProvider);
    var detailGet = repository.getSubjectDetail(widget.id);
    await _prefetchFirstScreen(generation);
    var result = await detailGet;
    if (!mounted || generation != _loadGeneration) return;
    if (result.code != 0 || result.data == null) {
      setState(() => showError = true);
      await showRespErr(result, context);
      return;
    }
    _applySubject(result.data!);
  }

  void _applySubject(BangumiSubject subject) {
    setState(() => data = subject);
    var title = subject.nameCn.trim();
    if (title.isEmpty) title = subject.name.trim();
    ref
        .read(navStoreProvider.notifier)
        .updateSubjectTitle(subject: subject.id, title: title);
  }

  /// 刷新页面：保留当前内容，重新拉取条目详情与各子模块接口。
  ///
  /// 与 [init] 的区别是不清空 [data]，避免内容树被卸载重建：
  /// 子模块的展开状态、滚动位置得以保留，接口刷新也由这里显式触发，
  /// 不再依赖「组件是否被重建」这种时序副作用。
  Future<void> refresh() async {
    if (!mounted || _refreshing) return;
    var generation = _loadGeneration;
    setState(() => _refreshing = true);
    try {
      var result = await ref
          .read(bangumiRepositoryProvider)
          .getSubjectDetail(widget.id);
      if (!mounted || generation != _loadGeneration) return;
      if (result.code != 0 || result.data == null) {
        await showRespErr(result, context);
        return;
      }
      _applySubject(result.data!);
      await _refreshSubModules();
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  /// 重新拉取收藏及已访问页签的接口数据。
  ///
  /// 未访问过的页签会被跳过，首次进入时才会请求。
  Future<void> _refreshSubModules({List<GlobalKey>? keys}) async {
    for (var key
        in keys ??
            [
              _collectionKey,
              _episodesKey,
              _relationsKey,
              _charactersKey,
              _personsKey,
              _commentsKey,
            ]) {
      var state = key.currentState;
      if (state is! SubjectDetailRefreshable) continue;
      // State 与 mixin 无继承关系，`is` 不会做类型提升，这里显式转换。
      await (state as SubjectDetailRefreshable).refresh();
    }
  }

  Future<void> _prefetchFirstScreen(int generation) async {
    var subjectId = int.tryParse(widget.id);
    if (subjectId == null) return;
    var repository = ref.read(bangumiRepositoryProvider);
    var authorization = ref.read(bgmUserStoreProvider);
    var user = authorization.user;
    var identity = (user?.id, authorization.accessToken);
    BangumiUserSubjectCollection? local;
    if (user != null) {
      local = await repository.getLocalCollection(subjectId);
      if (!mounted || generation != _loadGeneration) return;
      if (local != null) {
        collectProvider.set(true, type: local.type, epStatus: local.epStatus);
      }
    }
    var marking = user == null ? null : ref.read(episodeMarkProvider.notifier);
    _prefetch = SubjectDetailPrefetch(
      repository: repository,
      subject: subjectId,
      username: user?.id.toString(),
      collected: local != null,
      progressAccount: marking?.currentAccount(),
      progressVersion: marking?.progressVersion ?? 0,
      isCurrent: () {
        if (!mounted || generation != _loadGeneration) return false;
        var current = ref.read(bgmUserStoreProvider);
        return identity == (current.user?.id, current.accessToken);
      },
    );
  }

  @override
  void dispose() {
    _loadGeneration++;
    collectProvider.dispose();
    rssProvider.dispose();
    super.dispose();
  }

  Future<void> searchRss() async {
    if (data == null) {
      await BtInfobar.error(context, '数据为空');
      return;
    }
    var subject = data!;
    var repo = ref.read(bmfRepositoryProvider);
    var currentBmf = await repo.read(subject.id);
    if (!mounted) return;
    var behavior = ref.read(appStoreProvider).rssSelectionBehavior;
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      dismissWithEsc: true,
      builder: (_) => SubjectRssSearchDialog(
        subjectId: subject.id,
        title: subject.nameCn.isEmpty ? subject.name : subject.nameCn,
        currentRss: currentBmf?.rss,
        selectionBehavior: behavior,
        onSubscribe: (dialogContext, rss) async {
          var check = await repo.checkRss(rss, excludeSubject: subject.id);
          if (!dialogContext.mounted || !mounted) return false;
          if (check) {
            await BtInfobar.error(dialogContext, '该RSS已经被其他BMF使用');
            return false;
          }
          var bmf =
              await repo.read(subject.id) ??
              AppBmfModel(
                subject: subject.id,
                title: subject.nameCn.isEmpty ? subject.name : subject.nameCn,
                airDate: subject.date,
              );
          bmf = bmf.withSelectedRss(rss, behavior: behavior);
          var scheduled = await repo.write(bmf);
          // 写入已按自动更新设置发起过一次拉取，只为关闭自动更新的订阅补一次。
          if (!scheduled) await repo.refreshRss(bmf);
          if (mounted) rssProvider.set(rss, force: true);
          if (dialogContext.mounted) {
            await BtInfobar.success(dialogContext, '成功设置 RSS');
          }
          return true;
        },
      ),
    );
  }

  /// 根据标签搜索动画
  void searchByTag(String tag) {
    var normalizedTag = tag.trim();
    if (normalizedTag.isEmpty) return;

    var title = SubjectSearchPage.titleForTag(normalizedTag);
    ref
        .read(navStoreProvider.notifier)
        .addNavItem(
          PaneItem(
            icon: const Icon(FluentIcons.search),
            title: Text(title),
            body: SubjectSearchPage(tag: normalizedTag),
          ),
          title,
        );
  }

  /// 打开章节详情子页面
  void openEpisode(int episode) {
    var id = episode.toString();
    if (_episodeId == id) return;
    setState(() => _episodeId = id);
  }

  /// 关闭章节详情子页面，回到条目详情
  void closeEpisode() {
    if (_episodeId == null) return;
    setState(() => _episodeId = null);
  }

  /// 从章节详情跳转到条目详情。
  ///
  /// 章节所属条目就是当前页面时直接返回，避免“跳到自己在看的条目”
  /// 却仍停在章节详情上；其它条目才打开（或切换到）对应页签。
  void openSubjectFromEpisode(BangumiEpisodeSubject subject) {
    if (subject.id.toString() == widget.id) {
      closeEpisode();
      return;
    }
    var name = subject.nameCn.trim().isEmpty
        ? subject.name.trim()
        : subject.nameCn.trim();
    ref
        .read(navStoreProvider.notifier)
        .addNavItemB(
          type: subject.type.label,
          subject: subject.id,
          paneTitle: name,
        );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    var subject = int.tryParse(widget.id);
    if (subject != null) {
      ref.listen(episodeMarkRefreshProvider(subject), (_, value) {
        var event = value.asData?.value;
        var account = ref.read(bgmUserStoreProvider).user?.id.toString();
        if (event == null || event.account.split(':').first != account) return;
        unawaited(_refreshAfterEpisodeMark());
      });
    }
    var episodeId = _episodeId;
    // 章节详情是条目详情的下一级页面：条目详情的内容树保持挂载，
    // 返回时不会丢掉页签选择与滚动位置。
    return IndexedStack(
      sizing: StackFit.expand,
      index: episodeId == null ? 0 : 1,
      children: [
        buildSubjectPage(),
        if (episodeId != null)
          EpisodeDetailPage(
            id: episodeId,
            onBack: closeEpisode,
            onOpenSubject: openSubjectFromEpisode,
            onOpenEpisode: openEpisode,
          ),
      ],
    );
  }

  /// 构建条目详情页
  Widget buildSubjectPage() {
    return ScaffoldPage(
      header: buildHeader(),
      content: Stack(
        fit: StackFit.expand,
        children: [
          BTContentFrame(maxWidth: 1440, child: buildContent()),
          // 手动刷新不会卸载内容树，接口数据没变化时页面看不出动静，
          // 用顶部进度条显示刷新过程。
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

  Future<void> _refreshAfterEpisodeMark() async {
    try {
      for (var key in [_collectionKey, _episodesKey]) {
        if (!mounted) return;
        var child = key.currentState;
        if (child is SubjectDetailRefreshable) {
          await (child as SubjectDetailRefreshable).refresh();
        }
      }
    } catch (error) {
      BTLogTool.warn('标记看过后刷新详情失败：$error');
    }
  }
}
