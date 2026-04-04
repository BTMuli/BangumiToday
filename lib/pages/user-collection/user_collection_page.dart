// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

// Project imports:
import '../../models/bangumi/bangumi_enum.dart';
import '../../store/bgm_user_hive.dart';
import '../../ui/bt_infobar.dart';
import 'uc_pw_tab.dart';

/// user-collection.tv 用户收藏页面
class UserCollectionPage extends ConsumerStatefulWidget {
  /// 构造函数
  const UserCollectionPage({super.key});

  @override
  ConsumerState<UserCollectionPage> createState() => _UserCollectionPageState();
}

/// user-collection.tv 用户收藏页面状态
class _UserCollectionPageState extends ConsumerState<UserCollectionPage>
    with AutomaticKeepAliveClientMixin {
  /// tabIndex
  int tabIndex = 0;

  /// 保存状态
  @override
  bool get wantKeepAlive => true;

  /// 构建标签
  List<Tab> buildTabs() {
    var values = [
      BangumiCollectionType.doing,
      BangumiCollectionType.wish,
      BangumiCollectionType.collect,
      BangumiCollectionType.onHold,
      BangumiCollectionType.dropped,
    ];
    var result = <Tab>[];
    for (var i = 0; i < values.length; i++) {
      var type = values[i];
      result.add(
        Tab(
          selectedBackgroundColor: WidgetStateColor.resolveWith(
            (_) => FluentTheme.of(context).accentColor,
          ),
          icon: Icon(type.icon),
          text: Text(type.label),
          body: UcpTabWidget(type),
        ),
      );
    }
    return result;
  }

  /// 刷新授权
  Future<void> refreshAuth() async {
    var hiveUser = BgmUserHive();
    var result = await hiveUser.refreshAuth(force: true);
    if (!mounted) return;
    if (result == null) {
      await BtInfobar.info(context, '授权未过期，无需刷新');
    } else if (result) {
      await BtInfobar.success(context, '授权刷新成功');
    } else {
      await BtInfobar.error(context, '授权刷新失败');
    }
  }

  /// 构建底部
  Widget buildFooter() {
    return Row(
      children: [
        Button(
          onPressed: refreshAuth,
          child: const Text('刷新授权'),
        ),
        SizedBox(width: 12.w),
        Image.asset('assets/images/platforms/bangumi-logo.png'),
      ],
    );
  }

  /// build
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return TabView(
      tabs: buildTabs(),
      header: Image.asset('assets/images/platforms/bangumi-text.png'),
      currentIndex: tabIndex,
      onChanged: (index) => setState(() => tabIndex = index),
      footer: buildFooter(),
      closeButtonVisibility: CloseButtonVisibilityMode.never,
      tabWidthBehavior: TabWidthBehavior.sizeToContent,
    );
  }
}
