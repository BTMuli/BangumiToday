import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 侧边栏状态提供者
final navStoreProvider = ChangeNotifierProvider<BTNavStore>((ref) {
  return BTNavStore();
});

/// 侧边栏状态，用于控制侧边栏动态组件的加载与卸载
class BTNavStore extends ChangeNotifier {
  /// 当前索引
  int curIndex = 0;

  /// 上一次的索引
  int lastIndex = 0;

  /// 侧边栏动态组件
  final List<PaneItem> _navItems = [];

  /// 获取侧边栏动态组件
  List<PaneItem> get navItems => _navItems;

  /// 设置当前索引
  void setCurIndex(int index) {
    lastIndex = curIndex;
    curIndex = index;
    notifyListeners();
  }

  /// 添加侧边栏动态组件
  void addNavItem(PaneItem item) {
    item = PaneItem(
      title: item.title,
      body: item.body,
      icon: item.icon,
      trailing: IconButton(
        icon: Icon(FluentIcons.clear),
        onPressed: () {
          removeNavItem(item);
        },
      ),
    );
    // 查找是否已经存在
    final index = _navItems.indexWhere(
      (element) => element.title.toString() == item.title.toString(),
    );
    if (index != -1) {
      // 存在则更新
      _navItems[index] = item;
    } else {
      // 不存在则添加
      _navItems.add(item);
    }
    notifyListeners();
    toNav(item.title.toString());
  }

  /// 跳转到指定侧边栏
  void toNav(String title) {
    final index = _navItems.indexWhere(
      (element) => element.title.toString() == title,
    );
    if (index != -1) {
      lastIndex = curIndex;
      curIndex = index + 3;
      notifyListeners();
    }
  }

  /// 移除侧边栏组件-通过title
  void removeNavItemByTitle(String title) {
    final index = _navItems.indexWhere(
      (element) => element.title.toString() == title,
    );
    if (index != -1) {
      _navItems.removeAt(index);
      if (lastIndex > _navItems.length + 2) {
        curIndex = 0;
      } else {
        curIndex = lastIndex;
      }
      notifyListeners();
    }
  }

  /// 移除侧边栏动态组件
  void removeNavItem(PaneItem item) {
    _navItems.remove(item);
    if (lastIndex > _navItems.length + 2) {
      curIndex = 0;
    } else {
      curIndex = lastIndex;
    }
    notifyListeners();
  }
}
