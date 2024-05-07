// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

// Project imports:
import '../models/hive/nav_model.dart';
import '../pages/bangumi/bangumi_detail.dart';

/// 侧边栏状态提供者
final navStoreProvider = ChangeNotifierProvider<BTNavStore>((ref) {
  var store = BTNavStore();
  var items = Hive.box<BtmAppNavHive>('nav').values.toList();
  for (var item in items) {
    store.addNavItemB(subject: item.subjectId, paneTitle: item.title);
  }
  store.goIndex(0);
  return store;
});

/// 侧边栏状态，用于控制侧边栏动态组件的加载与卸载
class BTNavStore extends ChangeNotifier {
  /// 保留的顶部固定侧边栏
  final int topNavCount = 4;

  /// 当前索引
  int curIndex = 0;

  /// 上一次的索引
  int lastIndex = 0;

  /// 侧边栏动态组件
  final List<BtmAppNavItem> _navItems = [];

  /// 获取侧边栏动态组件
  List<PaneItem> get navItems {
    return _navItems.map((e) => e.body).toList();
  }

  /// 设置当前索引
  void setCurIndex(int index) {
    lastIndex = curIndex;
    curIndex = index;
    notifyListeners();
  }

  /// 获取navIndex
  int getNavIndex(BtmAppNavItemType type, String? title, String? param) {
    var res = -1;
    if (type == BtmAppNavItemType.app) {
      res = _navItems.indexWhere(
        (e) => e.title == title && e.type == BtmAppNavItemType.app,
      );
    } else {
      res = _navItems.indexWhere(
        (e) => e.param == param && e.type == BtmAppNavItemType.subject,
      );
    }
    return res;
  }

  /// 前往指定index
  void goIndex(int index) {
    lastIndex = curIndex;
    curIndex = index;
    notifyListeners();
  }

  /// 封装-添加条目详情侧边栏动态组件
  void addNavItemB({
    String type = '条目',
    required int subject,
    String? paneTitle,
  }) {
    var title = '$type详情 $subject';
    if (paneTitle != null && paneTitle.isNotEmpty) title = paneTitle;
    var pane = PaneItem(
      icon: const Icon(FluentIcons.info),
      title: Text(title),
      body: BangumiDetail(id: subject.toString()),
    );
    var paneType = BtmAppNavItemType.subject;
    var param = 'subjectDetail_$subject';
    addNavItem(pane, title, type: paneType, param: param);
  }

  /// 添加侧边栏动态组件
  void addNavItem(
    PaneItem item,
    String title, {
    BtmAppNavItemType type = BtmAppNavItemType.app,
    String? param,
    bool jump = true,
  }) {
    item = PaneItem(
      title: item.title,
      body: item.body,
      icon: item.icon,
      trailing: IconButton(
        icon: const Icon(FluentIcons.clear),
        onPressed: () {
          removeNavItem(title, type: type, param: param);
        },
      ),
    );
    var navItem = BtmAppNavItem(
      type: type,
      title: title,
      param: param,
      body: item,
    );
    var findIndex = getNavIndex(type, title, param);
    if (findIndex != -1) {
      _navItems[findIndex] = navItem;
    } else {
      _navItems.add(navItem);
    }
    if (type == BtmAppNavItemType.subject) {
      var subject = param!.replaceAll('subjectDetail_', '');
      var hiveItem = BtmAppNavHive(title: title, subjectId: int.parse(subject));
      Hive.box<BtmAppNavHive>('nav').put(subject, hiveItem);
    }
    notifyListeners();
    if (!jump) return;
    lastIndex = curIndex;
    if (findIndex != -1) {
      curIndex = findIndex + topNavCount;
    } else {
      curIndex = _navItems.length + topNavCount - 1;
    }
    notifyListeners();
  }

  /// 移除侧边栏动态组件
  void removeNavItem(
    String title, {
    BtmAppNavItemType type = BtmAppNavItemType.app,
    String? param,
  }) {
    var findIndex = getNavIndex(type, title, param);
    if (findIndex == -1) return;
    _navItems.removeAt(findIndex);
    if (lastIndex > _navItems.length + topNavCount - 1) {
      curIndex = 0;
    } else {
      curIndex = lastIndex;
    }
    if (type == BtmAppNavItemType.subject) {
      var subject = param!.replaceAll('subjectDetail_', '');
      Hive.box<BtmAppNavHive>('nav').delete(subject);
    }
    notifyListeners();
  }
}
