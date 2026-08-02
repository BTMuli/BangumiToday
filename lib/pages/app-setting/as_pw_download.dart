// Dart imports:
import 'dart:math';

// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../database/app/app_config.dart';
import '../../models/app/bt_download_config.dart';
import '../../store/bt_download_store.dart';
import '../../ui/bt_infobar.dart';

class AppConfigDownloadWidget extends ConsumerStatefulWidget {
  const AppConfigDownloadWidget({super.key});

  @override
  ConsumerState<AppConfigDownloadWidget> createState() =>
      _AppConfigDownloadWidgetState();
}

class _AppConfigDownloadWidgetState
    extends ConsumerState<AppConfigDownloadWidget> {
  static const _maxRateLimitKiB = 0x7fffffff ~/ 1024;

  BtDownloadConfig _config = const BtDownloadConfig();
  bool _loading = true;
  bool _saving = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    try {
      var config = await BtsAppConfig().readBtDownloadConfig();
      if (!mounted) return;
      setState(() {
        _config = config;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      _config.validate();
      await BtsAppConfig().writeBtDownloadConfig(_config);
      try {
        await ref.read(btDownloadStoreProvider).configure(_config.toJson());
      } catch (_) {
        if (mounted) {
          await BtInfobar.warn(context, '设置已保存，将在下载引擎下次启动时应用');
        }
        return;
      }
      if (mounted) await BtInfobar.success(context, '下载设置已保存');
    } catch (error) {
      if (mounted) await BtInfobar.error(context, '保存下载设置失败：$error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _numberSetting({
    required String title,
    required String description,
    required int value,
    required int min,
    required int max,
    required ValueChanged<int> onChanged,
  }) {
    return ListTile(
      title: Text(title),
      subtitle: Text(description),
      trailing: SizedBox(
        width: 180,
        child: NumberBox<int>(
          value: value,
          min: min,
          max: max,
          mode: SpinButtonPlacementMode.inline,
          onChanged: _saving
              ? null
              : (next) {
                  if (next != null) onChanged(next);
                },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Expander(
      leading: const Icon(FluentIcons.download),
      header: const Text('下载引擎'),
      content: _loading
          ? const Center(child: ProgressRing())
          : _loadError != null
          ? InfoBar(
              title: const Text('无法读取下载设置'),
              content: Text(_loadError!),
              severity: InfoBarSeverity.error,
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _numberSetting(
                  title: '同时下载任务数',
                  description: '允许并行下载的最大任务数量',
                  value: _config.activeDownloads,
                  min: 1,
                  max: 64,
                  onChanged: (value) => setState(
                    () => _config = _config.copyWith(activeDownloads: value),
                  ),
                ),
                _numberSetting(
                  title: '下载限速（KiB/s）',
                  description: '设为 0 表示不限速',
                  value: _config.downloadRateLimitKiB,
                  min: 0,
                  max: _maxRateLimitKiB,
                  onChanged: (value) => setState(
                    () => _config = _config.copyWith(
                      downloadRateLimit: value * 1024,
                    ),
                  ),
                ),
                _numberSetting(
                  title: '上传限速（KiB/s）',
                  description: '设为 0 表示不限速；默认限制为 1024 KiB/s',
                  value: _config.uploadRateLimitKiB,
                  min: 0,
                  max: _maxRateLimitKiB,
                  onChanged: (value) => setState(
                    () => _config = _config.copyWith(
                      uploadRateLimit: value * 1024,
                    ),
                  ),
                ),
                _numberSetting(
                  title: '全局连接数',
                  description: '下载引擎允许建立的最大连接数量',
                  value: _config.connectionsLimit,
                  min: 1,
                  max: 10000,
                  onChanged: (value) => setState(() {
                    _config = _config.copyWith(
                      connectionsLimit: value,
                      connectionsPerTask: min(
                        _config.connectionsPerTask,
                        value,
                      ),
                    );
                  }),
                ),
                _numberSetting(
                  title: '单任务连接数',
                  description: '每个下载任务允许建立的最大连接数量',
                  value: _config.connectionsPerTask,
                  min: 1,
                  max: _config.connectionsLimit,
                  onChanged: (value) => setState(
                    () => _config = _config.copyWith(connectionsPerTask: value),
                  ),
                ),
                _numberSetting(
                  title: '磁力元数据超时（秒）',
                  description: '超过该时间仍未获取到元数据时将任务标记为失败',
                  value: _config.metadataTimeoutSeconds,
                  min: 1,
                  max: 86400,
                  onChanged: (value) => setState(
                    () => _config = _config.copyWith(
                      metadataTimeoutSeconds: value,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox.square(
                            dimension: 16,
                            child: ProgressRing(strokeWidth: 2),
                          )
                        : const Text('保存设置'),
                  ),
                ),
              ],
            ),
    );
  }
}
