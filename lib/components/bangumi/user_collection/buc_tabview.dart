// Dart imports:
import 'dart:math';

// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

// Project imports:
import '../../../controller/app/page_controller.dart';
import '../../../controller/app/progress_controller.dart';
import '../../../database/bangumi/bangumi_collection.dart';
import '../../../models/bangumi/bangumi_enum.dart';
import '../../../models/bangumi/bangumi_enum_extension.dart';
import '../../../models/bangumi/bangumi_model.dart';
import '../../../store/nav_store.dart';
import '../../app/app_infobar.dart';
import 'buc_card.dart';

/// 用户收藏 tab
class BucTabView extends ConsumerStatefulWidget {
  /// 收藏类型
  final BangumiCollectionType type;

  /// 构造
  const BucTabView(this.type, {super.key});

  @override
  ConsumerState<BucTabView> createState() => _BucTabState();
}

/// 用户收藏 tab 状态
class _BucTabState extends ConsumerState<BucTabView>
    with AutomaticKeepAliveClientMixin {
  /// 收藏类型
  BangumiCollectionType get type => widget.type;

  /// progress controller
  final ProgressController progress = ProgressController();

  /// 查找
  final TextEditingController searchController = TextEditingController();

  /// 每页展示数量
  final int limit = 12;

  /// 数据库
  final BtsBangumiCollection sqlite = BtsBangumiCollection();

  /// page controller
  BtcPageController pageController = BtcPageController.defaultInit();

  /// 数据
  List<BangumiUserSubjectCollection> data = [];

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
    Future.delayed(Duration.zero, () async {
      await loadData();
    });
  }

  /// dispose
  @override
  void dispose() {
    searchController.dispose();
    pageController.dispose();
    super.dispose();
  }

  /// 获取数据
  Future<void> loadData() async {
    var list = await sqlite.getByType(type);
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    if (list.isNotEmpty) {
      data = list;
      setState(() {});
    }
    pageController = BtcPageController(
      total: (list.length / limit).ceil(),
      cur: 1,
      onChanged: (page) async => setState(() {}),
    );
  }

  /// 跳转
  void jump(BangumiUserSubjectCollection subject) => ref
      .read(navStoreProvider)
      .addNavItemB(type: subject.subjectType.label, subject: subject.subjectId);

  /// 构建 item
  Widget buildItem(BuildContext context, AutoSuggestBoxItem<dynamic> item) {
    return ListTile(
      trailing: IconButton(
        icon: const Icon(FluentIcons.info),
        onPressed: () => jump(item.value as BangumiUserSubjectCollection),
      ),
      title: Text(item.label, maxLines: 1, overflow: TextOverflow.ellipsis),
      onPressed: () {
        searchController.text = item.label;
        setState(() {});
      },
    );
  }

  /// 构建AutoSuggestBoxItem
  AutoSuggestBoxItem<BangumiUserSubjectCollection> buildAutoSuggestBoxItem(
    BangumiUserSubjectCollection item,
  ) {
    var label = item.subject.nameCn;
    if (item.subject.nameCn.isEmpty) label = item.subject.name;
    return AutoSuggestBoxItem<BangumiUserSubjectCollection>(
      value: item,
      label: label,
      semanticLabel: label,
      onSelected: () async {
        searchController.text = label;
      },
    );
  }

  /// 构建搜索框
  /// todo 改成下拉列表
  Widget buildSearch(BuildContext context) {
    return AutoSuggestBox<BangumiUserSubjectCollection>(
      controller: searchController,
      items: data.map(buildAutoSuggestBoxItem).toList(),
      itemBuilder: buildItem,
    );
  }

  /// 构建刷新按钮
  /// todo，改成从api获取，并将数据保存到数据库
  Widget buildRefresh(BuildContext context) {
    return IconButton(
      icon: const Icon(FluentIcons.refresh),
      onPressed: () async {
        data.clear();
        pageController.cur = 1;
        await loadData();
        if (context.mounted) await BtInfobar.success(context, '刷新成功');
      },
    );
  }

  /// 构建顶部
  Widget buildTop(BuildContext context) {
    var titleStyle = FluentTheme.of(context).typography.subtitle;
    return Row(children: [
      SizedBox(width: 8.w),
      Text('共 ${data.length} 部', style: titleStyle),
      SizedBox(width: 8.w),
      buildRefresh(context),
      SizedBox(width: 8.w),
      SizedBox(width: 600.w, child: buildSearch(context)),
      const Spacer(),
      PageWidget(pageController),
      SizedBox(width: 8.w),
    ]);
  }

  /// 构建列表
  Widget buildList() {
    if (showData.isEmpty) {
      return const Center(child: Text('没有数据'));
    }
    return GridView(
      controller: ScrollController(),
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: 10 / 7,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      children: showData.map((e) => BucCard(data: e)).toList(),
    );
  }

  /// 构建
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(children: [
      buildTop(context),
      SizedBox(height: 8.h),
      Expanded(child: buildList()),
    ]);
  }
}
