// Package imports:
import 'package:fluent_ui/fluent_ui.dart';

/// 宽屏内容容器：将内容约束在 [maxWidth] 内并水平居中，
/// 避免超宽屏上文字与控件被过度拉伸。
class BTContentFrame extends StatelessWidget {
  const BTContentFrame({super.key, required this.child, this.maxWidth = 1200});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
