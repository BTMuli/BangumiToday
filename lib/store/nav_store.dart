import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 侧边栏状态提供者
final navStoreProvider = ChangeNotifierProvider<BTNavStore>((ref) {
  return BTNavStore();
});

/// 侧边栏状态，用于控制侧边栏动态组件的加载与卸载
/// todo 拓展方法，提升侧边栏标题可读性
class BTNavStore extends ChangeNotifier {
  /// 保留的顶部固定侧边栏
  final int topNavCount = 3;

  /// 当前索引
  int curIndex = 0;

  /// 上一次的索引
  int lastIndex = 0;

  /// 侧边栏动态组件
  final Map<String, PaneItem> _navMap = {};

  /// 获取侧边栏动态组件
  List<PaneItem> get navItems => _navMap.values.toList();

  /// 设置当前索引
  void setCurIndex(int index) {
    lastIndex = curIndex;
    curIndex = index;
    notifyListeners();
  }

  /// 添加侧边栏动态组件
  void addNavItem(PaneItem item, String title) {
    debugPrint("addNavItem $title");
    item = PaneItem(
      title: item.title,
      body: item.body,
      icon: item.icon,
      trailing: IconButton(
        icon: Icon(FluentIcons.clear),
        onPressed: () {
          removeNavItem(title);
        },
      ),
    );
    if (_navMap.containsKey(title)) {
      _navMap[title] = item;
    } else {
      _navMap.putIfAbsent(title, () => item);
    }
    notifyListeners();
    toNav(title);
  }

  /// 跳转到指定侧边栏
  void toNav(String title) {
    final index = _navMap.keys.toList().indexOf(title);
    if (index != -1) {
      lastIndex = curIndex;
      curIndex = index + topNavCount;
      notifyListeners();
    }
  }

  /// 移除侧边栏动态组件
  void removeNavItem(String title) {
    debugPrint("removeNavItem $title");
    if (!_navMap.containsKey(title)) return;
    _navMap.remove(title);
    if (lastIndex > _navMap.length + topNavCount - 1) {
      curIndex = 0;
    } else {
      curIndex = lastIndex;
    }
    notifyListeners();
  }
}
