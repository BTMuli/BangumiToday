// Package imports:
import 'package:fluent_ui/fluent_ui.dart';

// Project imports:
import '../../core/theme/bt_theme.dart';

class BTIconToggleOption<T> {
  const BTIconToggleOption({
    required this.value,
    required this.label,
    required this.icon,
  });

  final T value;
  final String label;
  final IconData icon;
}

/// 共用背景的紧凑图标切换组，始终保留一个选中项。
class BTIconToggleGroup<T> extends StatelessWidget {
  const BTIconToggleGroup({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final T value;
  final List<BTIconToggleOption<T>> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    const padding = WidgetStatePropertyAll(EdgeInsetsDirectional.all(8));
    var style = ToggleButtonThemeData(
      checkedButtonStyle: ToggleButtonTheme.of(
        context,
      ).checkedButtonStyle?.copyWith(padding: padding),
      uncheckedButtonStyle: ButtonStyle(
        padding: padding,
        backgroundColor: HyperlinkButton.backgroundColor(
          FluentTheme.of(context),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BTRadius.smallBR),
        ),
      ),
    );
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: BTColors.surfaceSecondary(context),
        borderRadius: BTRadius.mediumBR,
        border: Border.all(color: BTColors.divider(context)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var index = 0; index < options.length; index++) ...[
            if (index > 0) const SizedBox(width: 2),
            Tooltip(
              message: options[index].label,
              child: Semantics(
                label: options[index].label,
                selected: value == options[index].value,
                child: ToggleButton(
                  checked: value == options[index].value,
                  style: style,
                  onChanged: (checked) {
                    if (checked) onChanged(options[index].value);
                  },
                  child: Icon(options[index].icon, size: 14),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
