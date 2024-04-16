import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../controller/app/progress_controller.dart';
import '../../../database/bangumi/bangumi_collection.dart';
import '../../../models/bangumi/bangumi_enum.dart';
import '../../../models/bangumi/bangumi_model.dart';
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

  /// todo 增加筛选条件

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

  /// 构建顶部
  Widget buildTop(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(8),
      child: Row(
        children: [
          Text(
            '共${data.length}部',
            style: FluentTheme.of(context).typography.subtitle,
          ),
          Spacer(),
          IconButton(
            icon: Icon(FluentIcons.refresh),
            onPressed: loadData,
          ),
        ],
      ),
    );
  }

  /// 构建列表
  Widget buildList() {
    if (data.isEmpty) {
      return Center(
        child: Text('没有数据'),
      );
    }
    return GridView(
      controller: ScrollController(),
      padding: EdgeInsets.all(8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
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
      ConstrainedBox(
        constraints: BoxConstraints(maxHeight: 900.h),
        child: buildList(),
      ),
    ]);
  }
}
