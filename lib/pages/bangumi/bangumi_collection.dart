import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../components/app/app_infobar.dart';
import '../../components/bangumi/user/collection_card.dart';
import '../../database/bangumi/bangumi_collection.dart';
import '../../database/bangumi/bangumi_user.dart';
import '../../models/bangumi/bangumi_enum.dart';
import '../../models/bangumi/bangumi_enum_extension.dart';
import '../../models/bangumi/bangumi_model.dart';
import '../../request/bangumi/bangumi_api.dart';
import '../../store/nav_store.dart';

/// bangummi.tv 用户收藏页面
class BangumiCollectionPage extends ConsumerStatefulWidget {
  /// 构造函数
  const BangumiCollectionPage({super.key});

  @override
  ConsumerState<BangumiCollectionPage> createState() =>
      _BangumiCollectionPageState();
}

/// bangummi.tv 用户收藏页面状态
class _BangumiCollectionPageState extends ConsumerState<BangumiCollectionPage>
    with AutomaticKeepAliveClientMixin {
  /// 数据库
  final BtsBangumiCollection sqlite = BtsBangumiCollection();

  /// 用户
  final BtsBangumiUser sqliteUser = BtsBangumiUser();

  /// api
  final BtrBangumiApi api = BtrBangumiApi();

  /// tabIndex
  int tabIndex = 0;

  /// 保存状态
  @override
  bool get wantKeepAlive => false;

  /// 初始化
  @override
  void initState() {
    super.initState();
  }

  ///  根据type获取icon
  IconData getIcon(BangumiCollectionType type) {
    switch (type) {
      case BangumiCollectionType.wish:
        return FluentIcons.add_bookmark;
      case BangumiCollectionType.collect:
        return FluentIcons.heart;
      case BangumiCollectionType.doing:
        return FluentIcons.play;
      case BangumiCollectionType.onHold:
        return FluentIcons.archive;
      case BangumiCollectionType.dropped:
        return FluentIcons.cancel;
      default:
        return FluentIcons.warning;
    }
  }

  /// 构建标签页
  Widget buildTabBody(BangumiCollectionType type) {
    return FutureBuilder<List<BangumiUserSubjectCollection>>(
      future: sqlite.getByType(type),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ProgressRing(),
                SizedBox(height: 20.h),
                Text('正在加载数据...'),
              ],
            ),
          );
        }
        if (snapshot.hasError) {
          return Center(
            child: Text('加载失败'),
          );
        }
        var data = snapshot.data!;
        return GridView(
          controller: ScrollController(),
          padding: EdgeInsets.all(12.sp),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 400.w / 280.h,
            mainAxisSpacing: 8.h,
            crossAxisSpacing: 7.w,
          ),
          children: data.map((e) => BucCard(data: e)).toList(),
        );
      },
    );
  }

  /// 构建标签
  List<Tab> buildTabs() {
    var values = BangumiCollectionType.values;
    var result = <Tab>[];
    for (var i = 0; i < values.length; i++) {
      var type = values[i];
      if (type == BangumiCollectionType.unknown) continue;
      result.add(Tab(
        icon: Icon(getIcon(type)),
        text: Text(type.label),
        body: buildTabBody(type),
      ));
    }
    return result;
  }

  /// 构建头部
  Widget buildHeader() {
    return Row(
      children: [
        Image.asset('assets/images/platforms/bangumi-text.png'),
        SizedBox(width: 8.w),
        Text('用户收藏'),
      ],
    );
  }

  /// 构建底部
  Widget buildFooter() {
    return Row(children: [
      // 关闭页面
      FilledButton(
        child: Text('关闭'),
        onPressed: () {
          ref.read(navStoreProvider).removeNavItem('Bangumi-用户收藏');
        },
      ),
      SizedBox(width: 16.w),
      Image.asset('assets/images/platforms/bangumi-logo.png'),
      SizedBox(width: 16.w),
    ]);
  }

  /// build
  /// todo 目前还是拿 calendar 页面组件来用，得写个新的组件
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return TabView(
      tabs: buildTabs(),
      header: buildHeader(),
      currentIndex: tabIndex,
      onChanged: (index) async {
        if (index == tabIndex) {
          await BtInfobar.warn(context, '已经在当前标签页');
          return;
        }
        tabIndex = index;
        setState(() {});
      },
      footer: buildFooter(),
      closeButtonVisibility: CloseButtonVisibilityMode.never,
      tabWidthBehavior: TabWidthBehavior.sizeToContent,
    );
  }
}
