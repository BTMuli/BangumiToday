// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_material_design_icons/flutter_material_design_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../core/theme/bt_theme.dart';
import '../../core/utils/get_theme_label.dart';
import '../../models/app/rss_selection_behavior.dart';
import '../../store/app_store.dart';
import '../../ui/bt_icon.dart';
import '../../widgets/common/bt_icon_toggle_group.dart';
import '../../widgets/common/bt_setting_section.dart';
import 'accent_color_dialog.dart';
import 'app_setting_storage.dart';

class AppConfigInfoWidget extends ConsumerStatefulWidget {
  const AppConfigInfoWidget({super.key});

  @override
  ConsumerState<AppConfigInfoWidget> createState() =>
      _AppConfigInfoWidgetState();
}

class _AppConfigInfoWidgetState extends ConsumerState<AppConfigInfoWidget> {
  /// 当前主题
  ThemeMode get curThemeMode => ref.watch(appStoreProvider).themeMode;

  /// 当前主题色
  AccentColor get curAccentColor =>
      ref.watch(appStoreProvider).effectiveAccentColor;

  /// 关闭主窗口后是否隐藏到托盘
  bool get minimizeToTray => ref.watch(appStoreProvider).minimizeToTray;

  /// 构建主题模式切换按钮组
  Widget buildThemeToggle() {
    var themes = getThemeModeConfigList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('主题模式', style: BTTypography.bodyStrong(context)),
        SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var theme in themes)
              ToggleButton(
                checked: curThemeMode == theme.cur,
                onChanged: (v) async {
                  if (!v) return;
                  await ref
                      .read(appStoreProvider.notifier)
                      .setThemeMode(theme.cur);
                },
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(theme.icon, size: 14),
                      SizedBox(width: 6),
                      Text(theme.label),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  /// 选择自定义主题色，确认后生成完整的深浅色阶并保存。
  Future<void> _selectCustomAccentColor() async {
    var initialColor = ref
        .read(appStoreProvider)
        .effectiveAccentColor
        .normal
        .withValues(alpha: 1);
    var color = await showAccentColorDialog(
      context,
      initialColor: initialColor,
    );
    if (color == null || !mounted) return;
    await ref
        .read(appStoreProvider.notifier)
        .setAccentColor(color.withValues(alpha: 1).toAccentColor());
  }

  /// 构建主题色切换按钮组
  Widget buildColorToggle() {
    var currentColorValue = curAccentColor.colorValue;
    var isCustomColor = !Colors.accentColors.any(
      (color) => currentColorValue == color.colorValue,
    );
    const toggleStyle = ToggleButtonThemeData(
      checkedButtonStyle: ButtonStyle(
        padding: WidgetStatePropertyAll(EdgeInsets.zero),
      ),
      uncheckedButtonStyle: ButtonStyle(
        padding: WidgetStatePropertyAll(EdgeInsets.zero),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('主题色', style: BTTypography.bodyStrong(context)),
        SizedBox(height: 8),
        if (curThemeMode == ThemeMode.system)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Text('跟随系统设置，无法更改主题色', style: BTTypography.caption(context)),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var color in Colors.accentColors)
                ToggleButton(
                  checked: currentColorValue == color.colorValue,
                  onChanged: (v) async {
                    if (!v) return;
                    await ref
                        .read(appStoreProvider.notifier)
                        .setAccentColor(color);
                  },
                  style: toggleStyle,
                  child: Tooltip(
                    message:
                        '#${color.colorValue.toRadixString(16).toUpperCase()}',
                    child: SizedBox.square(
                      dimension: 32,
                      child: ColoredBox(
                        color: currentColorValue == color.colorValue
                            ? color
                            : color.withValues(alpha: 0.35),
                      ),
                    ),
                  ),
                ),
              ToggleButton(
                checked: isCustomColor,
                onChanged: (_) async => _selectCustomAccentColor(),
                style: toggleStyle,
                child: Tooltip(
                  message: '自定义颜色',
                  child: SizedBox.square(
                    dimension: 32,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: isCustomColor ? curAccentColor : null,
                        gradient: isCustomColor
                            ? null
                            : LinearGradient(
                                colors: [
                                  Colors.magenta.withValues(alpha: 0.35),
                                  Colors.blue.withValues(alpha: 0.35),
                                  Colors.teal.withValues(alpha: 0.35),
                                ],
                              ),
                      ),
                      child: Icon(
                        FluentIcons.color,
                        size: 16,
                        color: isCustomColor
                            ? curAccentColor.basedOnLuminance()
                            : null,
                        semanticLabel: '自定义颜色',
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }

  /// 构建主题配置行（主题模式与主题色同一行）
  Widget buildThemeRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: buildThemeToggle()),
        SizedBox(width: 24),
        Expanded(child: buildColorToggle()),
      ],
    );
  }

  /// 构建关闭后最小化到托盘配置
  Widget buildMinimizeToTrayInfo() {
    return ListTile(
      leading: const BtIcon(FluentIcons.system),
      title: const Text('关闭后最小化到托盘'),
      subtitle: const Text('关闭主窗口时继续在后台运行，可从托盘菜单退出应用'),
      trailing: ToggleSwitch(
        checked: minimizeToTray,
        onChanged: (value) async {
          await ref.read(appStoreProvider.notifier).setMinimizeToTray(value);
        },
      ),
    );
  }

  Widget buildRssSelectionBehaviorInfo() {
    var behavior = ref.watch(appStoreProvider).rssSelectionBehavior;
    return ListTile(
      leading: const BtIcon(MdiIcons.rss),
      title: const Text('搜索 RSS 默认行为'),
      subtitle: const Text('替换：只保留选中的源；新增：保留已有源并添加'),
      trailing: BTIconToggleGroup<RssSelectionBehavior>(
        value: behavior,
        options: const [
          BTIconToggleOption(
            value: RssSelectionBehavior.replace,
            label: '替换：只保留选中的源',
            icon: FluentIcons.switch_widget,
          ),
          BTIconToggleOption(
            value: RssSelectionBehavior.add,
            label: '新增：保留已有源并添加',
            icon: FluentIcons.add,
          ),
        ],
        onChanged: (value) async {
          await ref
              .read(appStoreProvider.notifier)
              .setRssSelectionBehavior(value);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BTSettingSection(
      icon: FluentIcons.settings,
      title: '应用配置',
      subtitle: '主题、RSS、缓存与日志设置',
      initiallyExpanded: true,
      children: [
        buildThemeRow(),
        const BTSettingDivider(),
        buildMinimizeToTrayInfo(),
        buildRssSelectionBehaviorInfo(),
        const BTSettingDivider(),
        const AppSettingStorage(),
      ],
    );
  }
}
