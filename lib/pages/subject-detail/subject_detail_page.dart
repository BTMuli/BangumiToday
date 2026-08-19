// Dart imports:
import 'dart:async';

// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../controller/progress_controller.dart';
import '../../models/bangumi/bangumi_enum.dart';
import '../../models/bangumi/bangumi_model.dart';
import '../../models/database/app_bmf_model.dart';
import '../../models/hive/nav_model.dart';
import '../../plugins/mikan/mikan_api.dart';
import '../../plugins/mikan/models/mikan_model.dart';
import '../../providers/app_providers.dart';
import '../../ui/bt_dialog.dart';
import '../../ui/bt_infobar.dart';
import '../../widgets/bangumi/subject_detail/bsd_bmf_drawer.dart';
import '../../widgets/common/bt_content_frame.dart';
import '../../widgets/common/bt_drawer.dart';
import '../subject-search/subject_search_page.dart';
import 'sdp_action_bar.dart';
import 'sdp_layout_a.dart';
import 'sdp_layout_current.dart';
import 'sdp_layout_switcher.dart';
import 'sdp_view_data.dart';
import 'subject_layout_mode.dart';
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

  /// mikanApi
  final BtrMikanApi mikanApi = BtrMikanApi();

  /// collect provider
  final SubjectCollectStatProvider collectProvider =
      SubjectCollectStatProvider();

  /// rss provider
  final SubjectRssStatProvider rssProvider = SubjectRssStatProvider();

  /// progress
  late ProgressController progress = ProgressController();

  @override
  bool get wantKeepAlive => true;

  /// 是否显示错误组件
  bool showError = false;
  int _loadGeneration = 0;
  final GlobalKey _collectionKey = GlobalKey();
  final GlobalKey _episodesKey = GlobalKey();
  final GlobalKey _relationsKey = GlobalKey();

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
    setState(() => data = result.data);
  }

  bool _subjectHasBmf(int subjectId) {
    var list = ref
        .read(bmfListProvider)
        .maybeWhen(data: (items) => items, orElse: () => const <AppBmfModel>[]);
    for (var item in list) {
      if (item.subject == subjectId) return sdpBmfConfigured(item);
    }
    return false;
  }

  Future<void> _prefetchFirstScreen(int generation) async {
    var subjectId = int.tryParse(widget.id);
    if (subjectId == null) return;
    var repository = ref.read(bangumiRepositoryProvider);
    var user = ref.read(bgmUserHiveProvider).user;
    var layoutA =
        ref.read(subjectDetailLayoutModeProvider) == SubjectDetailLayoutMode.a;
    var hasBmf = _subjectHasBmf(subjectId);
    BangumiUserSubjectCollection? local;
    if (user != null) {
      local = await repository.getLocalCollection(subjectId);
      if (!mounted || generation != _loadGeneration) return;
      if (local != null) {
        collectProvider.set(true, type: local.type, epStatus: local.epStatus);
      }
      unawaited(repository.getCollectionSubject(user.id.toString(), subjectId));
    }
    var watching = hasBmf || local?.type == BangumiCollectionType.doing;
    if (!layoutA || watching) {
      unawaited(repository.getEpisodeList(subjectId, offset: 0, limit: 100));
      if (user != null && local != null) {
        unawaited(
          repository.getCollectionEpisodes(subjectId, offset: 0, limit: 100),
        );
      }
    }
  }

  @override
  void dispose() {
    _loadGeneration++;
    collectProvider.dispose();
    rssProvider.dispose();
    super.dispose();
  }

  Future<void> searchBangumi() async {
    if (data == null) {
      await BtInfobar.error(context, '数据为空');
      return;
    }
    var name = data?.nameCn == '' ? data?.name : data?.nameCn;
    if (name == null) {
      await BtInfobar.error(context, '数据为空');
      return;
    }
    var nameCheck = await showInput(
      context,
      title: '搜索番剧',
      content: '请输入番剧名称',
      value: name,
    );
    if (nameCheck == null) return;
    if (mounted) {
      progress = ProgressWidget.show(
        context,
        title: '搜索中',
        text: '正在搜索番剧: $nameCheck',
        progress: null,
      );
    }
    var resp = await mikanApi.searchBgm(nameCheck);
    progress.end();
    if (resp.code != 0) {
      if (mounted) await showRespErr(resp, context);
      return;
    }
    var items = resp.data as List<MikanSearchItemModel>;
    if (items.isEmpty) {
      if (mounted) await BtInfobar.error(context, '没有找到相关条目，请尝试更换搜索词');
      return;
    }
    if (mounted) await showSearchResult(context, items);
  }

  /// 根据标签搜索动画
  void searchByTag(String tag) {
    var normalizedTag = tag.trim();
    if (normalizedTag.isEmpty) return;

    var title = SubjectSearchPage.titleForTag(normalizedTag);
    ref
        .read(navStoreProvider)
        .addNavItem(
          PaneItem(
            icon: const Icon(FluentIcons.search),
            title: Text(title),
            body: SubjectSearchPage(tag: normalizedTag),
          ),
          title,
        );
  }

  /// 显示搜索结果
  Future<void> showSearchResult(
    BuildContext context,
    List<MikanSearchItemModel> items,
  ) async {
    var result = await showDialog(
      context: context,
      barrierDismissible: true,
      dismissWithEsc: true,
      builder: (context) {
        return ContentDialog(
          title: const Text('搜索结果'),
          content: ListView.builder(
            shrinkWrap: true,
            itemCount: items.length,
            itemBuilder: (context, index) {
              var item = items[index];
              return ListTile(
                title: Text(item.title),
                subtitle: Text(item.link),
                onPressed: () async {
                  var confirm = await showConfirm(
                    context,
                    title: '确认匹配？',
                    content: '将该结果设为BMF的RSS',
                  );
                  if (!confirm) return;
                  var repo = ref.read(bmfRepositoryProvider);
                  var check = await repo.checkRss(
                    item.rss,
                    excludeSubject: data!.id,
                  );
                  if (check) {
                    if (context.mounted) {
                      await BtInfobar.error(context, '该RSS已经被其他BMF使用');
                    }
                    return;
                  }
                  var bmf = await repo.read(data!.id);
                  if (bmf == null) {
                    bmf = AppBmfModel(
                      subject: data!.id,
                      title: data!.nameCn.isEmpty ? data!.name : data!.nameCn,
                      airDate: data!.date,
                      rss: item.rss,
                    );
                  } else {
                    bmf = bmf.copyWith(rss: item.rss);
                  }
                  await repo.write(bmf);
                  await repo.refreshRss(bmf);
                  rssProvider.set(item.rss);
                  if (context.mounted) {
                    await BtInfobar.success(context, '成功设置RSS');
                  }
                  if (context.mounted) Navigator.of(context).pop();
                },
              );
            },
          ),
          actions: [
            Button(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
          ],
        );
      },
    );
    if (result == null) return;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ScaffoldPage(
      header: buildHeader(),
      content: BTContentFrame(child: buildContent()),
    );
  }
}
