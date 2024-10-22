// Package imports:
import 'package:fluent_ui/fluent_ui.dart';

/// 对Icon进行简单的封装
class BtIcon extends StatefulWidget {
  /// 图标
  final IconData icon;

  /// 大小
  final double? size;

  /// 颜色
  final AccentColor? color;

  /// 构造函数
  const BtIcon(this.icon, {this.size, super.key, this.color});

  @override
  State<BtIcon> createState() => _BtIconState();
}

class _BtIconState extends State<BtIcon> {
  @override
  Widget build(BuildContext context) {
    return Icon(
      widget.icon,
      size: widget.size,
      color: widget.color?.normal ?? FluentTheme.of(context).accentColor.normal,
    );
  }
}
