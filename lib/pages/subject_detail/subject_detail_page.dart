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
import 'subject_detail_layout.dart';
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

  int _loadGeneration = 0;
  final GlobalKey _collectionKey = GlobalKey();
  final GlobalKey _episodesKey = GlobalKey();
  final GlobalKey _relationsKey = GlobalKey();
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

  /// 重新拉取收藏 / 章节 / 关联三个子模块的接口数据。
  ///
  /// 未访问过的页签会被跳过，首次进入时才会请求。
  Future<void> _refreshSubModules({List<GlobalKey>? keys}) async {
    for (var key in keys ?? [_collectionKey, _episodesKey, _relationsKey]) {
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
    var user = ref.read(bgmUserStoreProvider).user;
    BangumiUserSubjectCollection? local;
    if (user != null) {
      local = await repository.getLocalCollection(subjectId);
      if (!mounted || generation != _loadGeneration) return;
      if (local != null) {
        collectProvider.set(true, type: local.type, epStatus: local.epStatus);
      }
      unawaited(repository.getCollectionSubject(user.id.toString(), subjectId));
    }
    unawaited(repository.getEpisodeList(subjectId, offset: 0, limit: 100));
    if (user != null && local != null) {
      unawaited(
        repository.getCollectionEpisodes(subjectId, offset: 0, limit: 100),
      );
    }
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
