// Dart imports:
import 'dart:collection';
import 'dart:io';

// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:hive/hive.dart';

// Project imports:
import '../models/hive/nav_model.dart';
import '../pages/subject-detail/subject_detail_page.dart';
import '../widgets/app/nav_item_icon.dart';

final navStoreProvider = ChangeNotifierProvider<BTNavStore>((ref) {
  var store = BTNavStore();
  var items = Hive.box<BtmAppNavHive>('nav').values.toList();
  items.sort((a, b) => a.subjectId.compareTo(b.subjectId));
  for (var item in items) {
    store.addNavItemB(
      subject: item.subjectId,
      paneTitle: item.title,
      jump: false,
    );
  }
  store.goIndex(0);
  return store;
});

class BTNavStore extends ChangeNotifier {
  final int topNavCount = Platform.isWindows ? 4 : 3;

  /// 动态条目上限：超出后按最近使用顺序淘汰最旧的条目。
  static const int maxDynamicItems = 50;

  int curIndex = 0;

  final List<BtmAppNavItem> _navItems = [];
  final List<String> _recentParams = [];

  /// 已访问页面的 LRU，key 与侧边项位置无关。
  final LinkedHashSet<String> _alivePageKeys = LinkedHashSet();

  final int maxCachedPages = 10;

  static const String settingsPageKey = 'footer_settings';

  List<PaneItem> get navItems {
    return _navItems.map((e) => e.body).toList();
  }

  List<BtmAppNavItem> get dynamicNavItems {
    return List.unmodifiable(_navItems);
  }

  Set<String> get alivePageKeys => Set.unmodifiable(_alivePageKeys);

  String pageKeyForItem(BtmAppNavItem item) {
    if (item.param != null && item.param!.isNotEmpty) return item.param!;
    return 'app_${item.title}';
  }

  String pageKeyForIndex(int index) {
    if (index < 0) return 'const_0';
    if (index < topNavCount) return 'const_$index';
    var dyn = index - topNavCount;
    if (dyn >= 0 && dyn < _navItems.length) {
      return pageKeyForItem(_navItems[dyn]);
    }
    return settingsPageKey;
  }

  void setCurIndex(int index) {
    curIndex = index;
    _touchRecent(index);
    _visitPage(pageKeyForIndex(index));
    notifyListeners();
  }

  /// 将动态条目标记为最近使用（移到最后）。
  void _touchRecent(int index) {
    var navIndex = index - topNavCount;
    if (navIndex < 0 || navIndex >= _navItems.length) return;
    var param = _navItems[navIndex].param;
    if (param == null) return;
    _recentParams.remove(param);
    _recentParams.add(param);
  }

  void _visitPage(String key) {
    _alivePageKeys.remove(key);
    _alivePageKeys.add(key);
    while (_alivePageKeys.length > maxCachedPages) {
      var oldest = _alivePageKeys.first;
      if (oldest == key) break;
      _alivePageKeys.remove(oldest);
    }
  }

  void clearCache() {
    _alivePageKeys.clear();
    _visitPage(pageKeyForIndex(curIndex));
    notifyListeners();
  }

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

  void goIndex(int index) {
    curIndex = index;
    _touchRecent(index);
    _visitPage(pageKeyForIndex(index));
    notifyListeners();
  }

  /// 切换到 RSS & BMF 页面。
  void goToBmf() {
    goIndex(1);
  }

  /// 切换到下载管理页面。
  ///
  /// 下载管理只在 Windows 注册到主导航，其他平台返回 false。
  bool goToDownload() {
    if (!Platform.isWindows) return false;
    goIndex(3);
    return true;
  }

  void addNavItemB({
    String type = '条目',
    required int subject,
    String? paneTitle,
    bool jump = true,
  }) {
    var title = '$type详情 $subject';
    if (paneTitle != null && paneTitle.isNotEmpty) title = paneTitle;
    var paneType = BtmAppNavItemType.subject;
    var param = 'subjectDetail_$subject';
    var pane = PaneItem(
      icon: NavItemIcon(
        title: title,
        onClose: () => removeNavItem(title, type: paneType, param: param),
        onCloseOthers: () => removeNavItemOthers(param),
        onCloseAll: removeAllNavItems,
      ),
      title: Text(title),
      body: SubjectDetailPage(key: ValueKey(param), id: subject.toString()),
    );
    addNavItem(pane, title, type: paneType, param: param, jump: jump);
  }

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
      trailing: Tooltip(
        message: '关闭「$title」',
        child: IconButton(
          icon: const Icon(FluentIcons.clear),
          onPressed: () {
            removeNavItem(title, type: type, param: param);
          },
        ),
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
      _recentParams.remove(param);
      _recentParams.add(param);
      _trimToCap();
    }
    if (!jump) {
      if (curIndex == topNavCount + _navItems.length - 1) {
        curIndex = curIndex + 1;
      }
      notifyListeners();
      return;
    }
    if (findIndex != -1) {
      curIndex = findIndex + topNavCount;
    } else {
      curIndex = _navItems.length + topNavCount - 1;
    }
    _visitPage(pageKeyForIndex(curIndex));
    notifyListeners();
  }

  /// 超出上限时按最近使用顺序淘汰最旧的动态条目。
  void _trimToCap() {
    while (_navItems.length > maxDynamicItems && _recentParams.isNotEmpty) {
      var oldestParam = _recentParams.first;
      var navIndex = _navItems.indexWhere(
        (item) =>
            item.param == oldestParam && item.type == BtmAppNavItemType.subject,
      );
      if (navIndex == -1) {
        _recentParams.removeAt(0);
        continue;
      }
      var item = _navItems[navIndex];
      removeNavItem(item.title, type: item.type, param: item.param);
    }
  }

  /// 关闭除 [exceptParam] 以外的所有动态条目；为空时关闭全部动态条目。
  void removeNavItemOthers(String? exceptParam) {
    var targets = _navItems.where((item) => item.param != exceptParam).toList();
    for (var item in targets) {
      removeNavItem(item.title, type: item.type, param: item.param);
    }
  }

  /// 关闭全部动态条目。
  void removeAllNavItems() {
    removeNavItemOthers(null);
  }

  void removeNavItem(
    String title, {
    BtmAppNavItemType type = BtmAppNavItemType.app,
    String? param,
  }) {
    var findIndex = getNavIndex(type, title, param);
    if (findIndex == -1) return;

    var actualIndex = findIndex + topNavCount;
    var removedKey = pageKeyForItem(_navItems[findIndex]);
    _navItems.removeAt(findIndex);
    _alivePageKeys.remove(removedKey);
    if (param != null) _recentParams.remove(param);
    if (curIndex == actualIndex) {
      curIndex = 0;
    } else if (curIndex > actualIndex) {
      curIndex -= 1;
    }
    if (type == BtmAppNavItemType.subject) {
      var subject = param!.replaceAll('subjectDetail_', '');
      Hive.box<BtmAppNavHive>('nav').delete(subject);
    }
    _visitPage(pageKeyForIndex(curIndex));
    notifyListeners();
  }

  int get totalNavCount => topNavCount + _navItems.length;

  Map<String, dynamic> getStats() {
    return {
      'totalNavCount': totalNavCount,
      'alivePageKeys': _alivePageKeys.length,
      'curIndex': curIndex,
    };
  }
}
