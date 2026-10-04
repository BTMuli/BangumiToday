// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_material_design_icons/flutter_material_design_icons.dart';

/// 自动刷新用图标和选中底色共同表示状态，点击直接切换。
class BmfAutoUpdateButton extends StatelessWidget {
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const BmfAutoUpdateButton({
    super.key,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: enabled ? 'RSS 自动更新已开启，点击关闭' : 'RSS 自动更新已关闭，点击开启',
      child: ToggleButton(
        checked: enabled,
        onChanged: onChanged,
        child: Icon(
          enabled ? MdiIcons.autorenew : MdiIcons.syncOff,
          size: 17,
          semanticLabel: enabled ? '关闭 RSS 自动更新' : '开启 RSS 自动更新',
        ),
      ),
    );
  }
}
