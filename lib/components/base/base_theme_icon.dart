// Package imports:
import 'package:fluent_ui/fluent_ui.dart';

// Project imports:
import 'base_theme.dart';

/// 对Icon进行简单的封装
class BaseThemeIcon extends StatefulWidget {
  /// 图标
  final IconData icon;

  /// 大小
  final double? size;

  /// 颜色
  final BaseThemeColor color;

  /// 构造函数
  const BaseThemeIcon(
    this.icon, {
    this.size,
    super.key,
    this.color = BaseThemeColor.base,
  });

  const BaseThemeIcon.light(this.icon, {this.size, super.key})
      : color = BaseThemeColor.light;

  const BaseThemeIcon.dark(this.icon, {this.size, super.key})
      : color = BaseThemeColor.dark;

  const BaseThemeIcon.lighter(this.icon, {this.size, super.key})
      : color = BaseThemeColor.lighter;

  const BaseThemeIcon.darker(this.icon, {this.size, super.key})
      : color = BaseThemeColor.darker;

  const BaseThemeIcon.lightest(this.icon, {this.size, super.key})
      : color = BaseThemeColor.lightest;

  const BaseThemeIcon.darkest(this.icon, {this.size, super.key})
      : color = BaseThemeColor.darkest;

  @override
  State<BaseThemeIcon> createState() => _BaseThemeIconState();
}

class _BaseThemeIconState extends State<BaseThemeIcon> {
  @override
  Widget build(BuildContext context) {
    var base = FluentTheme.of(context).accentColor;
    var color = getColor(base, widget.color);
    return Icon(widget.icon, size: widget.size, color: color);
  }
}
