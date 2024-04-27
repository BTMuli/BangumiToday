// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

// Project imports:
import '../../../controller/app/progress_controller.dart';
import '../../../database/bangumi/bangumi_collection.dart';
import '../../../models/app/nav_model.dart';
import '../../../models/bangumi/bangumi_enum.dart';
import '../../../models/bangumi/bangumi_enum_extension.dart';
import '../../../models/bangumi/bangumi_model.dart';
import '../../../pages/bangumi/bangumi_detail.dart';
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

  /// 数据库
  final BtsBangumiCollection sqlite = BtsBangumiCollection();

  /// 数据
  /// todo 目前是采用全部加载，分页渲染的方式，后续可以考虑分页加载
  List<BangumiUserSubjectCollection> data = [];

  /// 查找
  final TextEditingController searchController = TextEditingController();

  /// 选中的数据
  BangumiUserSubjectCollection? selectedData;

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
    // 监听搜索框
    searchController.addListener(() {
      if (searchController.text.isEmpty) {
        selectedData = null;
        setState(() {});
      }
    });
  }

  /// dispose
  @override
  void dispose() {
    super.dispose();
  }

  /// 获取数据
  Future<void> loadData() async {
    var list = await sqlite.getByType(type);
    // 排序
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    if (list.isNotEmpty) {
      data = list;
      setState(() {});
    }
  }

  /// 构建 item
  Widget buildItem(
    BuildContext context,
    AutoSuggestBoxItem<dynamic> item,
  ) {
    var data = item.value as BangumiUserSubjectCollection;
    return ListTile(
      title: Text(item.label, maxLines: 1, overflow: TextOverflow.ellipsis),
      onPressed: () {
        searchController.text = item.label;
        selectedData = data;
        setState(() {});
      },
    );
  }

  /// 构建搜索框
  Widget buildSearch(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 8.w),
      child: AutoSuggestBox<BangumiUserSubjectCollection>(
        controller: searchController,
        items: data.map((item) {
          return AutoSuggestBoxItem<BangumiUserSubjectCollection>(
            value: item,
            label: item.subject.nameCn.isEmpty
                ? item.subject.name
                : item.subject.nameCn,
            onFocusChange: (focus) {
              if (focus) {
                debugPrint('focus on $item');
              }
            },
            semanticLabel: item.subject.nameCn.isEmpty
                ? item.subject.name
                : item.subject.nameCn,
            onSelected: () {
              searchController.text = item.subject.nameCn.isEmpty
                  ? item.subject.name
                  : item.subject.nameCn;
            },
          );
        }).toList(),
        itemBuilder: buildItem,
      ),
    );
  }

  /// 构建跳转
  Widget buildJump(BuildContext context) {
    return IconButton(
      icon: const Icon(FluentIcons.link),
      onPressed: () async {
        if (selectedData == null) {
          await BtInfobar.warn(context, '请选择一个条目');
          return;
        }
        var title =
            '${selectedData!.subjectType.label}详情 ${selectedData!.subjectId}';
        var pane = PaneItem(
          icon: const Icon(FluentIcons.info),
          title: Text(title),
          body: BangumiDetail(id: selectedData!.subjectId.toString()),
        );
        ref.read(navStoreProvider).addNavItem(
              pane,
              title,
              type: BtmAppNavItemType.bangumiSubject,
              param: 'subjectDetail_${selectedData!.subjectId}',
            );
      },
    );
  }

  /// 构建顶部
  Widget buildTop(BuildContext context) {
    return Container(
      height: 60,
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          Text(
            '共${data.length}部',
            style: FluentTheme.of(context).typography.subtitle,
          ),
          const Spacer(),
          SizedBox(
            width: 600.w,
            child: buildSearch(context),
          ),
          buildJump(context),
        ],
      ),
    );
  }

  /// 构建列表
  Widget buildList() {
    if (data.isEmpty) {
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
      children: data.map((e) => BucCard(data: e)).toList(),
    );
  }

  /// 构建
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(children: [
      buildTop(context),
      Expanded(child: buildList()),
    ]);
  }
}
