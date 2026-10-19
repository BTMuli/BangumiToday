// Flutter imports:
import 'package:flutter/services.dart';

// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../core/network/system_proxy.dart';
import '../../core/theme/bt_theme.dart';
import '../../models/app/proxy_settings.dart';
import '../../providers/app_providers.dart';
import '../../store/bt_download_store.dart';
import '../../ui/bt_icon.dart';
import '../../ui/bt_infobar.dart';
import '../../widgets/common/bt_setting_section.dart';

/// 网络设置。
class AppConfigNetworkWidget extends ConsumerStatefulWidget {
  /// 构造函数。
  const AppConfigNetworkWidget({super.key});

  @override
  ConsumerState<AppConfigNetworkWidget> createState() =>
      _AppConfigNetworkWidgetState();
}

class _AppConfigNetworkWidgetState
    extends ConsumerState<AppConfigNetworkWidget> {
  final _formKey = GlobalKey<FormState>();
  final _hostController = TextEditingController();
  final _portController = TextEditingController();
  bool _useSystemProxy = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadDraft(ref.read(appStoreProvider).proxySettings);
  }

  void _loadDraft(ProxySettings settings) {
    _useSystemProxy = settings.useSystemProxy;
    _hostController.text = settings.host;
    _portController.text = settings.port.toString();
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    super.dispose();
  }

  Future<void> _update(
    Future<void> Function() action, {
    required String success,
  }) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) await BtInfobar.success(context, success);
    } catch (error) {
      if (mounted) await BtInfobar.error(context, '保存代理设置失败：$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    if (!_useSystemProxy && !_formKey.currentState!.validate()) return;
    var saved = ref.read(appStoreProvider).proxySettings;
    var next = _useSystemProxy
        ? ProxySettings(host: saved.host, port: saved.port)
        : ProxySettings.manual(
            host: _hostController.text,
            port: _portController.text,
          );
    await _update(
      () => ref.read(appStoreProvider.notifier).setProxySettings(next),
      success: '代理设置已保存并生效',
    );
  }

  /// 描述应用当前实际下发的代理，供用户确认设置是否生效。
  String _proxyStatus(ProxySettings saved) {
    if (!SystemProxyController.enabled) {
      return '应用代理已关闭，网络请求直连';
    }
    var config = SystemProxyController.config;
    if (!config.isAvailable) {
      return '已启用应用代理，但没有可用的代理地址，网络请求当前会直连';
    }
    var source = saved.useSystemProxy ? '系统代理' : '手动代理';
    return '当前生效：${config.describe()}（$source）';
  }

  @override
  Widget build(BuildContext context) {
    var settings = ref.watch(appStoreProvider);
    ref.listen(appStoreProvider, (previous, next) {
      if (previous?.loaded != next.loaded ||
          previous?.proxySettings != next.proxySettings) {
        _loadDraft(next.proxySettings);
      }
    });
    var enabled = settings.loaded && !_busy;
    var savedSource = settings.proxySettings.useSystemProxy
        ? '系统代理'
        : '手动 HTTP 代理';
    var useDownloadProxy = ref.watch(
      btDownloadStoreProvider.select((store) => store.useSystemProxy),
    );
    var proxyUnavailable =
        SystemProxyController.enabled &&
        !SystemProxyController.config.isAvailable;
    var proxyStatus = _proxyStatus(settings.proxySettings);
    return BTSettingSection(
      icon: FluentIcons.network_tower,
      title: '网络设置',
      subtitle: '配置应用与下载引擎网络请求',
      initiallyExpanded: true,
      children: [
        ListTile(
          leading: const BtIcon(FluentIcons.globe),
          title: const Text('应用使用代理'),
          subtitle: const Text('按下方已保存的代理配置转发应用网络请求'),
          trailing: ToggleSwitch(
            checked: settings.useSystemProxy,
            onChanged: enabled
                ? (value) => _update(
                    () => ref
                        .read(appStoreProvider.notifier)
                        .setUseSystemProxy(value),
                    success: value ? '已启用应用代理' : '已关闭应用代理',
                  )
                : null,
          ),
        ),
        ListTile(
          leading: const BtIcon(FluentIcons.cloud_download),
          title: const Text('下载引擎使用代理'),
          subtitle: const Text('转发下载引擎的 HTTP 与 BT 流量，独立于应用代理开关，默认关闭'),
          trailing: ToggleSwitch(
            checked: useDownloadProxy,
            onChanged: enabled
                ? (value) => _update(
                    () => ref
                        .read(btDownloadStoreProvider.notifier)
                        .setUseSystemProxy(value),
                    success: value ? '已启用下载引擎代理' : '已关闭下载引擎代理',
                  )
                : null,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                proxyUnavailable ? FluentIcons.warning : FluentIcons.info,
                size: 14,
                color: proxyUnavailable
                    ? BTColors.warningLight(context)
                    : BTColors.textTertiary(context),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  proxyStatus,
                  style: BTTypography.caption(context).copyWith(
                    color: proxyUnavailable
                        ? BTColors.warningLight(context)
                        : null,
                  ),
                ),
              ),
            ],
          ),
        ),
        const BTSettingDivider(),
        ListTile(
          leading: const BtIcon(FluentIcons.settings),
          title: const Text('自动采用系统代理配置'),
          subtitle: const Text('开启时使用系统代理，关闭后使用下方手动配置；应用与下载引擎共用'),
          trailing: ToggleSwitch(
            checked: _useSystemProxy,
            onChanged: enabled
                ? (value) => setState(() => _useSystemProxy = value)
                : null,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!_useSystemProxy) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: InfoLabel(
                          label: '代理地址（IP 或主机名）',
                          child: TextFormBox(
                            controller: _hostController,
                            enabled: enabled,
                            placeholder: '127.0.0.1',
                            validator: ProxySettings.validateHost,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 120,
                        child: InfoLabel(
                          label: '端口',
                          child: TextFormBox(
                            controller: _portController,
                            enabled: enabled,
                            placeholder: '7890',
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            validator: ProxySettings.validatePort,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                Text('当前已保存：$savedSource。修改来源、地址或端口后请保存。'),
                const SizedBox(height: 12),
                SizedBox(
                  width: 120,
                  child: FilledButton(
                    onPressed: enabled ? _save : null,
                    child: _busy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: ProgressRing(strokeWidth: 2),
                          )
                        : const Text('保存代理设置'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
