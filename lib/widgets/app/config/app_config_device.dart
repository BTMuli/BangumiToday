// Package imports:
import 'package:device_info_plus/device_info_plus.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

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
    return Expander(
      leading: Icon(MdiIcons.laptopAccount),
      header: Text(diw.productName),
      content: Column(
        children: [
          ListTile(
            leading: Icon(MdiIcons.laptop),
            title: const Text('所在平台'),
            subtitle: Text(
              'Windows ${diw.displayVersion} '
              '${diw.majorVersion}.${diw.minorVersion}.${diw.buildNumber}'
              '(${diw.buildLab})',
            ),
          ),
          ListTile(
            leading: Icon(MdiIcons.devices),
            title: const Text('设备'),
            subtitle: Text('${diw.computerName} ${diw.productId}'),
          ),
          ListTile(
            leading: Icon(MdiIcons.identifier),
            title: const Text('标识符'),
            subtitle: Text(
              diw.deviceId.substring(1, diw.deviceId.length - 1),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return deviceInfo == null
        ? const Center(child: ProgressRing())
        : buildWinDeviceInfo(deviceInfo!);
  }
}
