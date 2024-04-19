import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../components/app/app_infobar.dart';
import '../../components/bangumi/user_collection/buc_tabview.dart';
import '../../models/bangumi/bangumi_enum.dart';
import '../../models/bangumi/bangumi_enum_extension.dart';
import '../../store/nav_store.dart';

/// bangumi.tv 用户收藏页面
class BangumiCollectionPage extends ConsumerStatefulWidget {
  /// 构造函数
  const BangumiCollectionPage({super.key});

  @override
  ConsumerState<BangumiCollectionPage> createState() =>
      _BangumiCollectionPageState();
}

/// bangumi.tv 用户收藏页面状态
class _BangumiCollectionPageState extends ConsumerState<BangumiCollectionPage>
    with AutomaticKeepAliveClientMixin {
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
        body: BucTabView(type),
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
        const Text('用户收藏'),
      ],
    );
  }

  /// 构建底部
  Widget buildFooter() {
    return Row(children: [
      FilledButton(
        child: const Text('关闭'),
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
