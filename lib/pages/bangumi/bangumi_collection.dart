// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

// Project imports:
import '../../models/bangumi/bangumi_enum.dart';
import '../../store/nav_store.dart';
import '../../widgets/bangumi/user_collection/buc_tabview.dart';

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
  bool get wantKeepAlive => true;

  /// 构建标签
  List<Tab> buildTabs() {
    var values = BangumiCollectionType.values;
    var result = <Tab>[];
    for (var i = 0; i < values.length; i++) {
      var type = values[i];
      if (type == BangumiCollectionType.unknown) continue;
      result.add(
        Tab(
          selectedBackgroundColor: FluentTheme.of(context).accentColor,
          icon: Icon(type.icon),
          text: Text(type.label),
          body: BucTabView(type),
        ),
      );
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
        onPressed: () =>
            ref.read(navStoreProvider).removeNavItem('Bangumi-用户收藏'),
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
      onChanged: (index) => setState(() => tabIndex = index),
      footer: buildFooter(),
      closeButtonVisibility: CloseButtonVisibilityMode.never,
      tabWidthBehavior: TabWidthBehavior.sizeToContent,
    );
  }
}
