// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../providers/app_providers.dart';
import '../../store/bt_download_store.dart';
import '../../ui/bt_icon.dart';
import '../../ui/bt_infobar.dart';
import '../../widgets/common/bt_setting_section.dart';

/// 网络设置。
class AppConfigNetworkWidget extends ConsumerWidget {
  /// 构造函数。
  const AppConfigNetworkWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var useSystemProxy = ref.watch(appStoreProvider).useSystemProxy;
    var useDownloadProxy = ref.watch(
      btDownloadStoreProvider.select((store) => store.useSystemProxy),
    );
    return BTSettingSection(
      icon: FluentIcons.network_tower,
      title: '网络设置',
      subtitle: '配置应用与下载引擎网络请求',
      initiallyExpanded: true,
      children: [
        ListTile(
          leading: const BtIcon(FluentIcons.globe),
          title: const Text('使用系统代理'),
          subtitle: const Text('使用 Windows 系统代理转发应用网络请求，开启代理软件后无需启用 TUN 模式'),
          trailing: ToggleSwitch(
            checked: useSystemProxy,
            onChanged: (value) async {
              try {
                await ref.read(appStoreProvider).setUseSystemProxy(value);
                if (context.mounted) {
                  await BtInfobar.success(
                    context,
                    value ? '已启用系统代理' : '已关闭系统代理',
                  );
                }
              } catch (error) {
                if (context.mounted) {
                  await BtInfobar.error(context, '保存系统代理设置失败：$error');
                }
              }
            },
          ),
        ),
        ListTile(
          leading: const BtIcon(FluentIcons.cloud_download),
          title: const Text('下载引擎使用系统代理'),
          subtitle: const Text('仅转发下载引擎的 HTTP 与 BT 流量，与上方应用代理相互独立，默认关闭'),
          trailing: ToggleSwitch(
            checked: useDownloadProxy,
            onChanged: (value) async {
              try {
                await ref
                    .read(btDownloadStoreProvider)
                    .setUseSystemProxy(value);
                if (context.mounted) {
                  await BtInfobar.success(
                    context,
                    value ? '已启用下载引擎系统代理' : '已关闭下载引擎系统代理',
                  );
                }
              } catch (error) {
                if (context.mounted) {
                  await BtInfobar.error(context, '保存下载代理设置失败：$error');
                }
              }
            },
          ),
        ),
      ],
    );
  }
}
