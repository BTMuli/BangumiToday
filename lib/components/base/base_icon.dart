// Package imports:
import 'package:fluent_ui/fluent_ui.dart';

/// 对Icon进行简单的封装
class BaseThemeIcon extends StatefulWidget {
  /// 图标
  final IconData icon;

  /// 大小
  final double? size;

  /// 构造函数
  const BaseThemeIcon(this.icon, {this.size, super.key});

  @override
  State<BaseThemeIcon> createState() => _BaseThemeIconState();
}

class _BaseThemeIconState extends State<BaseThemeIcon> {
  @override
  Widget build(BuildContext context) {
    return Icon(
      widget.icon,
      size: widget.size,
      color: FluentTheme.of(context).accentColor,
    );
  }
}
