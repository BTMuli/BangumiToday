// Dart imports:
import 'dart:io';

// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive_ce.dart';

// Project imports:
import '../models/hive/nav_model.dart';

final navStoreProvider = NotifierProvider<BTNavNotifier, BTNavState>(
  BTNavNotifier.new,
);

/// 导航状态：当前选中项、动态路由描述与仍需保留的页面键。
///
/// [navItems] 仅持有 [NavRouteDescriptor]（可值比较）；页面 Widget 由
/// shell 侧 factory 与 Notifier 的 app body 缓存组装。
class BTNavState {
  /// 构造函数
  BTNavState({
    required this.curIndex,
    required this.navItems,
    required this.aliveKeys,
    required this.topNavCount,
  });

  /// 当前选中索引
  final int curIndex;

  /// 动态路由描述
  final List<NavRouteDescriptor> navItems;

  /// 已访问页面的 LRU 键，按最近访问顺序排列。
  final List<String> aliveKeys;

  /// 常量条目数量
  final int topNavCount;

  /// 内嵌播放页索引；Windows 没有播放页，返回 -1。
  int get playbackIndex => Platform.isWindows ? -1 : 3;

  /// 动态条目只读视图
  List<NavRouteDescriptor> get dynamicNavItems => List.unmodifiable(navItems);

  /// 条目对应的页面键
  String pageKeyForItem(NavRouteDescriptor item) {
    if (item.param != null && item.param!.isNotEmpty) return item.param!;
    return 'app_${item.title}';
  }

  /// 索引对应的页面键
  String pageKeyForIndex(int index) {
    if (index < 0) return 'const_0';
    if (index < topNavCount) return 'const_$index';
    var dyn = index - topNavCount;
    if (dyn >= 0 && dyn < navItems.length) {
      return pageKeyForItem(navItems[dyn]);
    }
    return BTNavNotifier.settingsPageKey;
  }

  /// 拷贝
  BTNavState copyWith({
    int? curIndex,
    List<NavRouteDescriptor>? navItems,
    List<String>? aliveKeys,
  }) {
    return BTNavState(
      curIndex: curIndex ?? this.curIndex,
      navItems: navItems ?? this.navItems,
      aliveKeys: aliveKeys ?? this.aliveKeys,
      topNavCount: topNavCount,
    );
  }

  /// 与 Riverpod 的元素比对：选中项、路由描述与 LRU 键。
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! BTNavState) return false;
    return curIndex == other.curIndex &&
        topNavCount == other.topNavCount &&
        _sameItems(navItems, other.navItems) &&
        _sameKeys(aliveKeys, other.aliveKeys);
  }

  @override
  int get hashCode => Object.hash(
    curIndex,
    topNavCount,
    Object.hashAll(navItems),
    Object.hashAll(aliveKeys),
  );

  static bool _sameItems(
    List<NavRouteDescriptor> a,
    List<NavRouteDescriptor> b,
  ) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static bool _sameKeys(List<String> a, List<String> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

class BTNavNotifier extends Notifier<BTNavState> {
  /// 动态条目上限：超出后按最近使用顺序淘汰最旧的条目。
  static const int maxDynamicItems = 50;

  /// 应用设置页的固定页面键。
  static const String settingsPageKey = 'footer_settings';

  /// 同时保留的页面数量上限。
  static const int maxCachedPages = 10;

  /// 最近使用的动态条目参数，用于淘汰最旧条目。
  final List<String> _recentParams = [];

  /// App 类动态页 body 缓存（不进入 [BTNavState]）。
  final Map<String, Widget> _appPageBodies = {};

  /// App 类动态页 body 世代，用于标题不变时仍触发重建。
  final Map<String, int> _appPageEpochs = {};

  /// 当前选中索引
  int get curIndex => state.curIndex;

  /// 播放页索引
  int get playbackIndex => state.playbackIndex;

  /// 读取 app 类动态页缓存的 body。
  Widget? appPageBodyFor(NavRouteDescriptor route) {
    if (route.type != BtmAppNavItemType.app) return null;
    return _appPageBodies[state.pageKeyForItem(route)];
  }

  @override
  BTNavState build() {
    var hiveItems = Hive.box<BtmAppNavHive>('nav').values.toList();
    hiveItems.sort((a, b) => a.subjectId.compareTo(b.subjectId));
    // 按旧实现的顺序恢复动态条目并回到首页，全程只产生一个最终状态。
    var draft = BTNavState(
      curIndex: 0,
      navItems: <NavRouteDescriptor>[],
      aliveKeys: <String>[],
      topNavCount: 4,
    );
    for (var item in hiveItems) {
      draft = _addNavItemB(
        draft,
        subject: item.subjectId,
        paneTitle: item.title,
        jump: false,
      );
    }
    return _goIndex(draft, 0);
  }

  /// 标记页面被访问并维持 LRU 上限。
  BTNavState _visit(BTNavState draft, String key) {
    var alive = List<String>.of(draft.aliveKeys)..remove(key);
    alive.add(key);
    while (alive.length > maxCachedPages) {
      var oldest = alive.first;
      if (oldest == key) break;
      alive.remove(oldest);
    }
    return draft.copyWith(aliveKeys: alive);
  }

  /// 将动态条目标记为最近使用（移到最后）。
  void _touchRecent(BTNavState draft, int index) {
    var navIndex = index - draft.topNavCount;
    if (navIndex < 0 || navIndex >= draft.navItems.length) return;
    var param = draft.navItems[navIndex].param;
    if (param == null) return;
    _recentParams.remove(param);
    _recentParams.add(param);
  }

  BTNavState _goIndex(BTNavState draft, int index) {
    var next = draft.copyWith(curIndex: index);
    _touchRecent(next, index);
    return _visit(next, next.pageKeyForIndex(index));
  }

  /// 切换选中项
  void setCurIndex(int index) => state = _goIndex(state, index);

  /// 定位到指定索引
  void goIndex(int index) => state = _goIndex(state, index);

  /// 切换到今日放送页面。
  void goToCalendar() => goIndex(0);

  /// 切换到 RSS & BMF 页面。
  void goToBmf() => goIndex(1);

  /// 切换到下载管理页面。
  ///
  /// 下载管理只在 Windows 注册到主导航，其他平台返回 false。
  bool goToDownload() {
    if (!Platform.isWindows) return false;
    goIndex(2);
    return true;
  }

  /// 切换到应用设置页。
  void goToSettings() {
    goIndex(state.topNavCount + state.navItems.length);
  }

  /// 切换到内嵌播放页面；Windows 播放由独立窗口承载。
  void goToPlayback() {
    if (Platform.isWindows) return;
    goIndex(state.playbackIndex);
  }

  /// 查找动态条目索引
  int _navIndexOf(
    BTNavState draft,
    BtmAppNavItemType type,
    String? title,
    String? param,
  ) {
    var items = draft.navItems;
    if (type == BtmAppNavItemType.app) {
      return items.indexWhere(
        (e) => e.title == title && e.type == BtmAppNavItemType.app,
      );
    }
    return items.indexWhere(
      (e) => e.param == param && e.type == BtmAppNavItemType.subject,
    );
  }

  /// 添加条目详情页
  void addNavItemB({
    String type = '条目',
    required int subject,
    String? paneTitle,
    bool jump = true,
  }) {
    state = _addNavItemB(
      state,
      type: type,
      subject: subject,
      paneTitle: paneTitle,
      jump: jump,
    );
  }

  /// 同步已打开条目的名称，不创建条目或切换当前页面。
  void updateSubjectTitle({required int subject, required String title}) {
    if (title.trim().isEmpty) return;
    var param = 'subjectDetail_$subject';
    if (_navIndexOf(state, BtmAppNavItemType.subject, null, param) == -1) {
      return;
    }
    state = _addNavItemB(
      state,
      subject: subject,
      paneTitle: title,
      jump: false,
    );
  }

  BTNavState _addNavItemB(
    BTNavState draft, {
    String type = '条目',
    required int subject,
    String? paneTitle,
    bool jump = true,
  }) {
    if (subject <= 0) return draft;
    var param = 'subjectDetail_$subject';
    var findIndex = _navIndexOf(draft, BtmAppNavItemType.subject, null, param);
    var title = paneTitle?.trim() ?? '';
    // 通知和深链接可能只有 ID，重复打开时保留已经解析出的名称。
    if (title.isEmpty) {
      title = findIndex == -1
          ? '$type详情 $subject'
          : draft.navItems[findIndex].title;
    }
    if (findIndex != -1 && draft.navItems[findIndex].title == title) {
      return jump ? _goIndex(draft, findIndex + draft.topNavCount) : draft;
    }
    return _addNavItem(
      draft,
      NavRouteDescriptor(
        type: BtmAppNavItemType.subject,
        title: title,
        param: param,
        subjectId: subject,
      ),
      jump: jump,
    );
  }

  /// 添加动态条目
  void addNavItem(
    PaneItem item,
    String title, {
    BtmAppNavItemType type = BtmAppNavItemType.app,
    String? param,
    bool jump = true,
  }) {
    state = _addNavItemFromPane(
      state,
      item,
      title,
      type: type,
      param: param,
      jump: jump,
    );
  }

  BTNavState _addNavItemFromPane(
    BTNavState draft,
    PaneItem item,
    String title, {
    BtmAppNavItemType type = BtmAppNavItemType.app,
    String? param,
    bool jump = true,
  }) {
    var route = NavRouteDescriptor(
      type: type,
      title: title,
      param: param,
      subjectId: type == BtmAppNavItemType.subject && param != null
          ? int.tryParse(param.replaceAll('subjectDetail_', ''))
          : null,
    );
    if (type == BtmAppNavItemType.app && item.body != null) {
      var key = draft.pageKeyForItem(route);
      var epoch = (_appPageEpochs[key] ?? 0) + 1;
      _appPageEpochs[key] = epoch;
      _appPageBodies[key] = item.body!;
      route = NavRouteDescriptor(
        type: route.type,
        title: route.title,
        param: route.param,
        subjectId: route.subjectId,
        bodyEpoch: epoch,
      );
    }
    return _addNavItem(draft, route, jump: jump);
  }

  BTNavState _addNavItem(
    BTNavState draft,
    NavRouteDescriptor route, {
    bool jump = true,
  }) {
    var findIndex = _navIndexOf(draft, route.type, route.title, route.param);
    var items = List<NavRouteDescriptor>.of(draft.navItems);
    if (findIndex != -1) {
      items[findIndex] = route;
    } else {
      items.add(route);
    }

    var next = draft.copyWith(navItems: items);
    if (route.type == BtmAppNavItemType.subject) {
      var subject =
          route.subjectId ??
          int.parse(route.param!.replaceAll('subjectDetail_', ''));
      var hiveItem = BtmAppNavHive(title: route.title, subjectId: subject);
      Hive.box<BtmAppNavHive>('nav').put(subject.toString(), hiveItem);
      _recentParams.remove(route.param);
      _recentParams.add(route.param!);
      next = _trimToCap(next);
    }

    if (!jump) {
      if (findIndex == -1 &&
          next.curIndex == next.topNavCount + next.navItems.length - 1) {
        next = next.copyWith(curIndex: next.curIndex + 1);
      }
      return next;
    }

    var target = findIndex != -1
        ? findIndex + next.topNavCount
        : next.navItems.length + next.topNavCount - 1;
    next = next.copyWith(curIndex: target);
    return _visit(next, next.pageKeyForIndex(target));
  }

  /// 超出上限时按最近使用顺序淘汰最旧的动态条目。
  BTNavState _trimToCap(BTNavState draft) {
    var next = draft;
    while (next.navItems.length > maxDynamicItems && _recentParams.isNotEmpty) {
      var oldestParam = _recentParams.first;
      var navIndex = next.navItems.indexWhere(
        (item) =>
            item.param == oldestParam && item.type == BtmAppNavItemType.subject,
      );
      if (navIndex == -1) {
        _recentParams.removeAt(0);
        continue;
      }
      var item = next.navItems[navIndex];
      next = _removeNavItem(
        next,
        item.title,
        type: item.type,
        param: item.param,
      );
    }
    return next;
  }

  /// 关闭除 [exceptParam] 以外的所有动态条目；为空时关闭全部动态条目。
  void removeNavItemOthers(String? exceptParam) {
    var targets = state.navItems
        .where((item) => item.param != exceptParam)
        .toList();
    for (var item in targets) {
      removeNavItem(item.title, type: item.type, param: item.param);
    }
  }

  /// 关闭全部动态条目。
  void removeAllNavItems() {
    removeNavItemOthers(null);
  }

  /// 关闭指定动态条目
  void removeNavItem(
    String title, {
    BtmAppNavItemType type = BtmAppNavItemType.app,
    String? param,
  }) {
    state = _removeNavItem(state, title, type: type, param: param);
  }

  BTNavState _removeNavItem(
    BTNavState draft,
    String title, {
    BtmAppNavItemType type = BtmAppNavItemType.app,
    String? param,
  }) {
    var findIndex = _navIndexOf(draft, type, title, param);
    if (findIndex == -1) return draft;

    var actualIndex = findIndex + draft.topNavCount;
    var removed = draft.navItems[findIndex];
    var removedKey = draft.pageKeyForItem(removed);
    var items = List<NavRouteDescriptor>.of(draft.navItems)
      ..removeAt(findIndex);
    var curIndex = draft.curIndex;
    if (curIndex == actualIndex) {
      curIndex = 0;
    } else if (curIndex > actualIndex) {
      curIndex -= 1;
    }
    if (param != null) _recentParams.remove(param);
    _appPageBodies.remove(removedKey);
    _appPageEpochs.remove(removedKey);
    if (type == BtmAppNavItemType.subject) {
      var subject = param!.replaceAll('subjectDetail_', '');
      Hive.box<BtmAppNavHive>('nav').delete(subject);
    }

    var next = draft.copyWith(navItems: items, curIndex: curIndex);
    next = next.copyWith(
      aliveKeys: List<String>.of(next.aliveKeys)..remove(removedKey),
    );
    return _visit(next, next.pageKeyForIndex(curIndex));
  }
}
