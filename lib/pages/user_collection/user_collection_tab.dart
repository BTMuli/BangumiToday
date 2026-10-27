// Dart imports:
import 'dart:math';

// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../controller/page_controller.dart';
import '../../controller/progress_controller.dart';
import '../../models/bangumi/bangumi_enum.dart';
import '../../models/bangumi/bangumi_model.dart';
import '../../providers/app_providers.dart';
import '../../ui/bt_dialog.dart';
import '../../ui/bt_infobar.dart';
import '../../widgets/common/empty_state.dart';
import 'user_collection_card.dart';

/// 用户收藏 tab
class UserCollectionTab extends ConsumerStatefulWidget {
  /// 收藏类型
  final BangumiCollectionType type;

  /// 构造
  const UserCollectionTab(this.type, {super.key});

  @override
  ConsumerState<UserCollectionTab> createState() => _UserCollectionTabState();
}

/// 用户收藏 tab 状态
class _UserCollectionTabState extends ConsumerState<UserCollectionTab>
    with AutomaticKeepAliveClientMixin {
  /// 收藏类型
  BangumiCollectionType get type => widget.type;

  /// progress controller
  late ProgressController progress = ProgressController();

  /// 查找
  final TextEditingController searchController = TextEditingController();

  /// 每页展示数量
  final int limit = 12;

  /// 按卡片所需宽度排布，避免页面留白改变通用断点的列数。
  static const double _minimumCardWidth = 280;
  static const double _cardSpacing = 12;

  /// 用户Hive

  /// page controller
  BtcPageController pageController = BtcPageController.defaultInit();

  /// 数据
  List<BangumiUserSubjectCollection> data = [];
  int _loadRevision = 0;

  /// 展示数据
  List<BangumiUserSubjectCollection> get showData {
    if (pageController.cur == 0) {
      return [];
    }
    var start = (pageController.cur - 1) * limit;
    var end = min(start + limit, data.length);
    return data.sublist(start, end);
  }

  /// 保存状态
  @override
  bool get wantKeepAlive => false;

  /// 初始化
  @override
  void initState() {
    super.initState();
    pageController.onChanged = (_) async {
      if (mounted) setState(() {});
    };
    ref.listenManual(bangumiCollectionsProvider(type), (_, next) {
      next.whenData(_applyData);
    }, fireImmediately: true);
  }

  /// dispose
  @override
  void dispose() {
    _loadRevision++;
    searchController.dispose();
    pageController.dispose();
    super.dispose();
  }

  /// 获取数据
  Future<void> loadData() async {
    if (!mounted) return;
    var revision = ++_loadRevision;
    var list = await ref
        .read(bangumiRepositoryProvider)
        .getLocalCollections(type: type);
    if (!mounted || revision != _loadRevision) return;
    _applyData(list);
  }

  void _applyData(List<BangumiUserSubjectCollection> list) {
    if (!mounted) return;
    _loadRevision++;
    data = list.toList()..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    var pages = (data.length / limit).ceil();
    pageController.reset(
      total: pages,
      cur: pages == 0 ? 0 : pageController.cur.clamp(1, pages),
    );
    setState(() {});
  }

  /// 跳转
  void jump(BangumiUserSubjectCollection subject) => ref
      .read(navStoreProvider.notifier)
      .addNavItemB(
        type: subject.subjectType.label,
        subject: subject.subjectId,
        paneTitle: subject.subject.nameCn == ''
            ? subject.subject.name
            : subject.subject.nameCn,
      );

  /// 刷新收藏
  Future<void> freshCollection() async {
    if (!mounted || progress.isShow) return;
    progress = ProgressWidget.show(
      context,
      title: '刷新收藏信息',
      text: '正在刷新 ${type.label} 收藏信息',
      onTaskbar: true,
    );
    if (ref.read(bgmUserStoreProvider).user == null) {
      progress.end();
      if (mounted) await BtInfobar.error(context, '用户信息为空');
      return;
    }
    var repository = ref.read(bangumiRepositoryProvider);
    try {
      var resp = await repository.syncCollections(
        type: type,
        onProgress: (completed, total) {
          if (!mounted) return;
          progress.update(
            text: '获取收藏信息：$completed/$total',
            progress: total == 0 ? 100 : completed * 100 / total,
          );
        },
      );
      progress.end();
      if (!mounted) return;
      if (resp.code != 0) {
        await showRespErr(resp, context);
      } else {
        await loadData();
        if (mounted) await BtInfobar.success(context, '收藏信息同步完成');
      }
    } finally {
      progress.end();
    }
  }

  /// 构建 item
  AutoSuggestBoxItem<BangumiUserSubjectCollection> buildItem(
    BangumiUserSubjectCollection item,
  ) {
    var label = item.subject.nameCn;
    if (label.isEmpty) label = item.subject.name;
    return AutoSuggestBoxItem<BangumiUserSubjectCollection>(
      value: item,
      label: label,
      child: SizedBox(
        width: 400,
        child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );
  }

  /// 构建搜索框
  Widget buildJump(BuildContext context) {
    return AutoSuggestBox<BangumiUserSubjectCollection>(
      items: data.map(buildItem).toList(),
      onSelected: (item) async {
        if (item.value == null) {
          await BtInfobar.warn(context, '没有找到数据');
          return;
        }
        jump(item.value!);
      },
      placeholder: '搜索',
    );
  }

  /// 构建刷新按钮
  Widget buildRefresh(BuildContext context) {
    return Tooltip(
      message: '刷新数据 (长按从API刷新)',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(4)),
        child: IconButton(
          icon: const Icon(FluentIcons.refresh),
          onPressed: () async {
            data.clear();
            pageController.cur = 1;
            await loadData();
            if (context.mounted) await BtInfobar.success(context, '刷新成功');
          },
          onLongPress: () async {
            var check = await showConfirm(
              context,
              title: '是否从API刷新数据',
              content: '将从 bangumi.tv 获取数据',
            );
            if (!check || !mounted) return;
            await freshCollection();
          },
        ),
      ),
    );
  }

  /// 构建顶部
  Widget buildTop(BuildContext context) {
    var titleStyle = FluentTheme.of(context).typography.subtitle;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: FluentTheme.of(context).micaBackgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(type.icon, size: 20, color: FluentTheme.of(context).accentColor),
          SizedBox(width: 8),
          Text('共 ${data.length} 部', style: titleStyle),
          SizedBox(width: 12),
          buildRefresh(context),
          SizedBox(width: 12),
          Expanded(
            child: Container(
              constraints: BoxConstraints(maxWidth: 450),
              child: buildJump(context),
            ),
          ),
          SizedBox(width: 12),
          PageWidget(pageController),
        ],
      ),
    );
  }

  /// 构建列表
  Widget buildList(BuildContext context) {
    if (showData.isEmpty) {
      return BTEmptyState.noCollection(
        actionText: '浏览今日放送',
        onAction: () => ref.read(navStoreProvider.notifier).goToCalendar(),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        var columns = max(
          1,
          ((constraints.maxWidth + _cardSpacing) /
                  (_minimumCardWidth + _cardSpacing))
              .floor(),
        );
        return Container(
          margin: EdgeInsets.symmetric(vertical: 8),
          child: GridView.builder(
            padding: EdgeInsets.symmetric(vertical: 8),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              childAspectRatio: 10 / 7,
              mainAxisSpacing: _cardSpacing,
              crossAxisSpacing: _cardSpacing,
            ),
            itemCount: showData.length,
            scrollCacheExtent: const ScrollCacheExtent.pixels(500),
            itemBuilder: (context, index) => RepaintBoundary(
              key: ValueKey(showData[index].subjectId),
              child: UserCollectionCard(data: showData[index]),
            ),
          ),
        );
      },
    );
  }

  /// 构建
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Container(
      color: FluentTheme.of(context).scaffoldBackgroundColor,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          SizedBox(height: 12),
          buildTop(context),
          SizedBox(height: 12),
          Expanded(child: buildList(context)),
        ],
      ),
    );
  }
}
