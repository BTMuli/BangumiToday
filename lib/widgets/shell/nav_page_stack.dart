// Package imports:
import 'package:fluent_ui/fluent_ui.dart';

/// 按稳定 page key 保活的导航内容栈。
///
/// Fluent `NavigationView` 默认用 `selected` 索引起 `AnimatedSwitcher`，
/// 切页或前面的侧边项被删除导致索引前移时都会拆掉旧页面。此组件把已访问
/// 页面留在树里，只切换可见性。
class NavPageEntry {
  const NavPageEntry({required this.pageKey, required this.body});

  final String pageKey;
  final Widget body;
}

class NavPageStack extends StatelessWidget {
  const NavPageStack({
    super.key,
    required this.selectedKey,
    required this.pages,
  });

  final String selectedKey;
  final List<NavPageEntry> pages;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        for (var page in pages)
          Offstage(
            key: ValueKey(page.pageKey),
            offstage: page.pageKey != selectedKey,
            child: TickerMode(
              enabled: page.pageKey == selectedKey,
              child: page.body,
            ),
          ),
      ],
    );
  }
}
