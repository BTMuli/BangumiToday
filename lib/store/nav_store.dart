// Dart imports:
import 'dart:io';

// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce/hive_ce.dart';

// Project imports:
import '../models/hive/nav_model.dart';
import '../pages/subject_detail/subject_detail_page.dart';
import '../widgets/shell/nav_item_icon.dart';

final navStoreProvider = NotifierProvider<BTNavNotifier, BTNavState>(
  BTNavNotifier.new,
);

/// 导航状态：当前选中项、动态条目与仍需保留的页面键。
///
/// [navItems] 内部持有 [BtmAppNavItem]，包含页面 Widget 与回调，属于不可
/// 序列化的界面描述，因此状态只保证引用不可变，不做值相等比较；
/// [aliveKeys] 作为 LRU 判定依据需要值比较。
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

  /// 动态条目
  final List<BtmAppNavItem> navItems;

  /// 已访问页面的 LRU 键，按最近访问顺序排列。
  final List<String> aliveKeys;

  /// 常量条目数量
  final int topNavCount;

  /// 内嵌播放页索引；Windows 没有播放页，返回 -1。
  int get playbackIndex => Platform.isWindows ? -1 : 3;

  /// 侧边动态项
  List<PaneItem> get paneItems => navItems.map((e) => e.body).toList();

  /// 动态条目只读视图
  List<BtmAppNavItem> get dynamicNavItems => List.unmodifiable(navItems);

  /// 条目对应的页面键
  String pageKeyForItem(BtmAppNavItem item) {
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
    List<BtmAppNavItem>? navItems,
    List<String>? aliveKeys,
  }) {
    return BTNavState(
      curIndex: curIndex ?? this.curIndex,
      navItems: navItems ?? this.navItems,
      aliveKeys: aliveKeys ?? this.aliveKeys,
      topNavCount: topNavCount,
    );
  }

  /// 与 Riverpod 的元素比对：只关心选中项、条目集合与 LRU 键。
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
    Object.hashAll(navItems.map((e) => e.param ?? e.title)),
    Object.hashAll(aliveKeys),
  );

  static bool _sameItems(List<BtmAppNavItem> a, List<BtmAppNavItem> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!identical(a[i], b[i])) return false;
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

  /// 当前选中索引
  int get curIndex => state.curIndex;

  /// 播放页索引
  int get playbackIndex => state.playbackIndex;

  @override
  BTNavState build() {
    var hiveItems = Hive.box<BtmAppNavHive>('nav').values.toList();
    hiveItems.sort((a, b) => a.subjectId.compareTo(b.subjectId));
    // 按旧实现的顺序恢复动态条目并回到首页，全程只产生一个最终状态。
    var draft = BTNavState(
      curIndex: 0,
      navItems: <BtmAppNavItem>[],
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

  /// 切换到 RSS & BMF 页面。
  void goToBmf() => goIndex(1);

  /// 切换到下载管理页面。
  ///
  /// 下载管理只在 Windows 注册到主导航，其他平台返回 false。
  bool goToDownload() {
    if (!Platform.isWindows) return false;
    goIndex(3);
    return true;
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

  BTNavState _addNavItemB(
    BTNavState draft, {
    String type = '条目',
    required int subject,
    String? paneTitle,
    bool jump = true,
  }) {
    var title = '$type详情 $subject';
    if (paneTitle != null && paneTitle.isNotEmpty) title = paneTitle;
    var param = 'subjectDetail_$subject';
    var pane = PaneItem(
      icon: NavItemIcon(
        title: title,
        onClose: () =>
            removeNavItem(title, type: BtmAppNavItemType.subject, param: param),
        onCloseOthers: () => removeNavItemOthers(param),
        onCloseAll: removeAllNavItems,
      ),
      title: Text(title),
      body: SubjectDetailPage(key: ValueKey(param), id: subject.toString()),
    );
    return _addNavItem(
      draft,
      pane,
      title,
      type: BtmAppNavItemType.subject,
      param: param,
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
    state = _addNavItem(
      state,
      item,
      title,
      type: type,
      param: param,
      jump: jump,
    );
  }

  BTNavState _addNavItem(
    BTNavState draft,
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
    var findIndex = _navIndexOf(draft, type, title, param);
    var items = List<BtmAppNavItem>.of(draft.navItems);
    if (findIndex != -1) {
      items[findIndex] = navItem;
    } else {
      items.add(navItem);
    }

    var next = draft.copyWith(navItems: items);
    if (type == BtmAppNavItemType.subject) {
      var subject = param!.replaceAll('subjectDetail_', '');
      var hiveItem = BtmAppNavHive(title: title, subjectId: int.parse(subject));
      Hive.box<BtmAppNavHive>('nav').put(subject, hiveItem);
      _recentParams.remove(param);
      _recentParams.add(param);
      next = _trimToCap(next);
    }

    if (!jump) {
      if (next.curIndex == next.topNavCount + next.navItems.length - 1) {
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
    var removedKey = draft.pageKeyForItem(draft.navItems[findIndex]);
    var items = List<BtmAppNavItem>.of(draft.navItems)..removeAt(findIndex);
    var curIndex = draft.curIndex;
    if (curIndex == actualIndex) {
      curIndex = 0;
    } else if (curIndex > actualIndex) {
      curIndex -= 1;
    }
    if (param != null) _recentParams.remove(param);
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
