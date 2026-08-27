// Package imports:
import 'package:fluent_ui/fluent_ui.dart';

/// 未访问过的 Tab 不挂子树，避免 [initState] 拉网或读库。
///
/// 已访问过的 Tab 保留 [child]，配合页面级 KeepAlive 避免来回切换重复请求。
class BtLazyTabBody extends StatelessWidget {
  const BtLazyTabBody({super.key, required this.visited, required this.child});

  final bool visited;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!visited) return const SizedBox.shrink();
    return child;
  }
}
