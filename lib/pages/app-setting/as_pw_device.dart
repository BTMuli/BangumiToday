// Package imports:
import 'package:device_info_plus/device_info_plus.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_material_design_icons/flutter_material_design_icons.dart';

import '../../core/theme/bt_theme.dart';
import '../../ui/bt_icon.dart';
import '../../widgets/common/bt_card.dart';
import '../../widgets/common/bt_setting_section.dart';

class AppConfigDeviceWidget extends StatefulWidget {
  const AppConfigDeviceWidget({super.key});

  @override
  State<AppConfigDeviceWidget> createState() => _AppConfigDeviceWidgetState();
}

class _AppConfigDeviceWidgetState extends State<AppConfigDeviceWidget> {
  WindowsDeviceInfo? deviceInfo;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      deviceInfo = await DeviceInfoPlugin().windowsInfo;
      if (mounted) setState(() {});
    });
  }

  /// 构建 Windows 设备信息
  Widget buildWinDeviceInfo(WindowsDeviceInfo diw) {
    return BTSettingSection(
      icon: MdiIcons.laptopAccount,
      title: '设备信息',
      subtitle: diw.productName,
      initiallyExpanded: true,
      children: [
        ListTile(
          leading: const BtIcon(MdiIcons.laptop),
          title: const Text('所在平台'),
          subtitle: Text(
            'Windows ${diw.displayVersion} '
            '${diw.majorVersion}.${diw.minorVersion}.${diw.buildNumber}'
            '(${diw.buildLab})',
          ),
        ),
        ListTile(
          leading: const BtIcon(MdiIcons.devices),
          title: const Text('设备'),
          subtitle: Text('${diw.computerName} ${diw.productId}'),
        ),
        ListTile(
          leading: const BtIcon(MdiIcons.identifier),
          title: const Text('标识符'),
          subtitle: Text(diw.deviceId.substring(1, diw.deviceId.length - 1)),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (deviceInfo == null) {
      var isDark = FluentTheme.of(context).brightness == Brightness.dark;
      return BTCard(
        useAcrylic: true,
        backgroundColor: isDark
            ? const Color(0xFF3C3C3C).withValues(alpha: 0.8)
            : Colors.white.withValues(alpha: 0.95),
        useShadow: true,
        shadowLevel: BTShadowLevel.subtle,
        borderRadius: BTRadius.large,
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ProgressRing(),
            SizedBox(height: 12),
            Text('正在读取设备信息…', style: BTTypography.caption(context)),
          ],
        ),
      );
    }
    return buildWinDeviceInfo(deviceInfo!);
  }
}
