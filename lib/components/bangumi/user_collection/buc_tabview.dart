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
import '../../../request/bangumi/bangumi_api.dart';
import '../../../store/bgm_user_hive.dart';
import '../../../store/nav_store.dart';
import '../../app/app_dialog.dart';
import '../../app/app_dialog_resp.dart';
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
  late ProgressController progress = ProgressController();

  /// 查找
  final TextEditingController searchController = TextEditingController();

  /// 每页展示数量
  final int limit = 12;

  /// 用户Hive
  final BgmUserHive hive = BgmUserHive();

  /// api
  final BtrBangumiApi api = BtrBangumiApi();

  /// 收藏数据库
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

  /// 刷新收藏
  Future<void> freshCollection() async {
    progress = ProgressWidget.show(
      context,
      title: '刷新收藏信息',
      text: '正在刷新 ${type.label} 收藏信息',
      onTaskbar: true,
    );
    if (hive.user == null) {
      progress.end();
      if (mounted) await BtInfobar.error(context, '用户信息为空');
      return;
    }
    const limitC = 50;
    var offsetC = 0;
    var resp = await api.getCollectionSubjects(
      username: hive.user!.id.toString(),
      limit: limitC,
      offset: offsetC,
      collectionType: type,
    );
    if (resp.code != 0 || resp.data == null) {
      progress.end();
      if (mounted) await showRespErr(resp, context);
      return;
    }
    var checkFlag = true;
    var pageResp = resp.data as BangumiPageT<BangumiUserSubjectCollection>;
    var total = pageResp.total;
    var cnt = 0;
    while (checkFlag) {
      offsetC += pageResp.data.length;
      for (var item in pageResp.data) {
        await sqlite.write(item, check: false);
        progress.update(
          text: '[${item.subject.id}] ${item.subject.name}',
          progress: (cnt / total) * 100,
        );
        cnt++;
      }
      if (offsetC >= total) {
        checkFlag = false;
        progress.end();
        if (mounted) await BtInfobar.success(context, '收藏信息写入完成');
        break;
      }
      progress.update(
        text: '偏移：$offsetC，总计：$total',
        progress: (cnt / total) * 100,
      );
      resp = await api.getCollectionSubjects(
        username: hive.user!.id.toString(),
        limit: limitC,
        offset: offsetC,
        collectionType: type,
      );
      if (resp.code != 0 || resp.data == null) {
        progress.end();
        if (mounted) await showRespErr(resp, context);
        return;
      }
      pageResp = resp.data as BangumiPageT<BangumiUserSubjectCollection>;
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
        width: 400.w,
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
    return IconButton(
      icon: const Icon(FluentIcons.refresh),
      onPressed: () async {
        data.clear();
        pageController.cur = 1;
        await loadData();
        if (context.mounted) await BtInfobar.success(context, '刷新成功');
      },
      onLongPress: () async {
        var check = await showConfirmDialog(
          context,
          title: '是否从API刷新数据',
          content: '将从 bangumi.tv 获取数据',
        );
        if (!check) return;
        await freshCollection();
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
      SizedBox(width: 600.w, child: buildJump(context)),
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
      SizedBox(height: 8.h),
      buildTop(context),
      SizedBox(height: 8.h),
      Expanded(child: buildList()),
    ]);
  }
}
