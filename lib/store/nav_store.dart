import 'package:flutter/foundation.dart';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:hive/hive.dart';

import '../core/memory/memory_manager.dart';
import '../models/hive/nav_model.dart';
import '../pages/subject-detail/subject_detail_page.dart';

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
  final int topNavCount = kDebugMode ? 4 : 3;

  int curIndex = 0;

  final List<BtmAppNavItem> _navItems = [];

  final Set<int> _loadedIndices = {};

  final Map<int, Widget> _cachedBodies = {};

  final int maxCachedPages = 10;

  List<PaneItem> get navItems {
    return _navItems.map((e) => e.body).toList();
  }

  Set<int> get loadedIndices => Set.unmodifiable(_loadedIndices);

  bool isIndexLoaded(int index) => _loadedIndices.contains(index);

  void setCurIndex(int index) {
    if (curIndex != index) {
      _markIndexAsNotInUse(curIndex);
    }
    curIndex = index;
    _loadedIndices.add(index);
    _preloadAdjacent(index);
    _cleanupCache();
    notifyListeners();
  }

  void _markIndexAsNotInUse(int index) {
    var navIndex = index - topNavCount;
    if (navIndex >= 0 && navIndex < _navItems.length) {
      var item = _navItems[navIndex];
      var key = 'nav_item_${item.param ?? item.title}';
      MemoryManager.instance.unregisterDisposable(key);
    }
  }

  void _preloadAdjacent(int index) {
    for (int i = 1; i <= 2; i++) {
      var prevIndex = index - i;
      var nextIndex = index + i;
      if (prevIndex >= 0) _loadedIndices.add(prevIndex);
      if (nextIndex < topNavCount + _navItems.length) {
        _loadedIndices.add(nextIndex);
      }
    }
  }

  void _cleanupCache() {
    if (_cachedBodies.length <= maxCachedPages) return;

    var keysToRemove = <int>[];
    for (var key in _cachedBodies.keys) {
      if ((key - curIndex).abs() > 3) {
        keysToRemove.add(key);
      }
    }

    for (var key in keysToRemove) {
      _cachedBodies.remove(key);
      _loadedIndices.remove(key);
    }
  }

  void clearCache() {
    _cachedBodies.clear();
    _loadedIndices.clear();
    _loadedIndices.add(curIndex);
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
    _loadedIndices.add(index);
    notifyListeners();
  }

  void addNavItemB({
    String type = '条目',
    required int subject,
    String? paneTitle,
    bool jump = true,
  }) {
    var title = '$type详情 $subject';
    if (paneTitle != null && paneTitle.isNotEmpty) title = paneTitle;
    var pane = PaneItem(
      icon: const Icon(FluentIcons.info),
      title: Text(title),
      body: SubjectDetailPage(id: subject.toString()),
    );
    var paneType = BtmAppNavItemType.subject;
    var param = 'subjectDetail_$subject';
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
    _loadedIndices.add(curIndex);
    notifyListeners();
  }

  void removeNavItem(
    String title, {
    BtmAppNavItemType type = BtmAppNavItemType.app,
    String? param,
  }) {
    var findIndex = getNavIndex(type, title, param);
    if (findIndex == -1) return;

    var actualIndex = findIndex + topNavCount;
    _cachedBodies.remove(actualIndex);
    _loadedIndices.remove(actualIndex);

    _navItems.removeAt(findIndex);
    if (curIndex == actualIndex) {
      curIndex = 0;
    } else if (curIndex > actualIndex) {
      curIndex -= 1;
    }
    if (type == BtmAppNavItemType.subject) {
      var subject = param!.replaceAll('subjectDetail_', '');
      Hive.box<BtmAppNavHive>('nav').delete(subject);
    }
    notifyListeners();
  }

  int get totalNavCount => topNavCount + _navItems.length;

  Map<String, dynamic> getStats() {
    return {
      'totalNavCount': totalNavCount,
      'loadedIndices': _loadedIndices.length,
      'cachedBodies': _cachedBodies.length,
      'curIndex': curIndex,
    };
  }
}
