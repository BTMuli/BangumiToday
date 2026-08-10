// Dart imports:
import 'dart:math';

// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../core/services/bt_engine_client.dart';
import '../../core/services/windows_firewall_rule.dart';
import '../../core/theme/bt_theme.dart';
import '../../database/app/app_config.dart';
import '../../models/app/bt_download_config.dart';
import '../../models/app/bt_tracker_config.dart';
import '../../store/bt_download_store.dart';
import '../../store/tracker_hive.dart';
import '../../ui/bt_dialog.dart';
import '../../ui/bt_engine_switch.dart';
import '../../ui/bt_infobar.dart';
import '../../widgets/common/bt_setting_section.dart';

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
  BtTrackerConfig _trackerConfig = const BtTrackerConfig();
  final TextEditingController _sourceController = TextEditingController();
  final TextEditingController _manualTrackerController =
      TextEditingController();
  bool _loading = true;
  bool _saving = false;
  bool _refreshingTrackers = false;
  bool _firewallBusy = false;
  String? _loadError;
  EngineFirewallRuleStatus? _firewallStatus;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    try {
      var config = await BtsAppConfig().readBtDownloadConfig();
      var trackerConfig = TrackerHive().config;
      if (!mounted) return;
      setState(() {
        _config = config;
        _trackerConfig = trackerConfig;
        _sourceController.text = trackerConfig.sources.join('\n');
        _manualTrackerController.text = trackerConfig.manualTrackers.join('\n');
        _loading = false;
      });
      await _refreshFirewallStatus();
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
      if (_config.seedingEnabled && !_config.seedingDisclosureAccepted) {
        var confirmed = await showConfirm(
          context,
          title: '启用 BT 做种？',
          content:
              '做种会向 Tracker 和其他 Peer 暴露你的 IP，并产生上传流量。'
              '任务会在分享率或时间任一限制先达到后停止。',
        );
        if (!confirmed) return;
        _config = _config.copyWith(seedingDisclosureAccepted: true);
      }
      _config.validate();
      await _saveTrackerDraft();
      await BtsAppConfig().writeBtDownloadConfig(_config);
      try {
        await ref
            .read(btDownloadStoreProvider)
            .configure(
              _config.toEngineJson(
                additionalTrackers: TrackerHive().effectiveTrackers,
              ),
            );
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

  Future<void> _saveTrackerDraft() async {
    var sources = _sourceController.text
        .split(RegExp(r'[\r\n]+'))
        .map((source) => source.trim())
        .where((source) => source.isNotEmpty)
        .toSet()
        .toList(growable: false);
    var manualTrackers = parseTrackerText(
      _manualTrackerController.text,
      allowCommas: true,
    );
    var next = _trackerConfig.copyWith(
      sources: sources,
      manualTrackers: manualTrackers,
    );
    await TrackerHive().updateConfig(next);
    _trackerConfig = TrackerHive().config;
  }

  Future<void> _toggleEngine(bool enabled) async {
    if (enabled) {
      await enableDownloadEngine(ref, context);
      await _reloadConfig();
      await _refreshFirewallStatus();
      return;
    }

    var confirmed = await showConfirm(
      context,
      title: '关闭下载引擎？',
      content: '关闭后引擎进程将停止，正在进行的下载任务会暂停，可随时重新开启。',
    );
    if (!confirmed) return;
    try {
      await ref.read(btDownloadStoreProvider).disableEngine();
      await _reloadConfig();
      if (!mounted) return;
      await BtInfobar.success(context, '下载引擎已关闭');
    } catch (error) {
      if (mounted) await BtInfobar.error(context, '关闭下载引擎失败：$error');
    }
  }

  Future<void> _reloadConfig() async {
    var config = await BtsAppConfig().readBtDownloadConfig();
    if (!mounted) return;
    setState(() => _config = config);
  }

  Future<void> _refreshTrackerList() async {
    setState(() => _refreshingTrackers = true);
    try {
      await _saveTrackerDraft();
      await TrackerHive().refresh(force: true);
      if (!mounted) return;
      setState(() => _trackerConfig = TrackerHive().config);
      var error = _trackerConfig.lastUpdateError;
      if (error == null) {
        await BtInfobar.success(context, 'Tracker 列表已更新');
      } else {
        await BtInfobar.warn(context, error);
      }
    } catch (error) {
      if (mounted) await BtInfobar.error(context, '更新 Tracker 失败：$error');
    } finally {
      if (mounted) setState(() => _refreshingTrackers = false);
    }
  }

  Future<void> _refreshFirewallStatus() async {
    EngineFirewallRuleStatus status;
    try {
      status = await WindowsFirewallRuleService.instance.status(
        BtEngineClient.bundledExecutablePath(),
      );
    } catch (_) {
      status = EngineFirewallRuleStatus.unsupported;
    }
    if (!mounted) return;
    setState(() => _firewallStatus = status);
  }

  Future<void> _registerFirewallRule() async {
    setState(() => _firewallBusy = true);
    try {
      await WindowsFirewallRuleService.instance.register(
        BtEngineClient.bundledExecutablePath(),
      );
      await _refreshFirewallStatus();
      if (mounted) await BtInfobar.success(context, '防火墙规则已注册');
    } catch (error) {
      if (mounted) await BtInfobar.warn(context, '注册防火墙规则失败：$error');
    } finally {
      if (mounted) setState(() => _firewallBusy = false);
    }
  }

  Future<void> _unregisterFirewallRule() async {
    var confirmed = await showConfirm(
      context,
      title: '移除防火墙规则？',
      content: '移除后，下载引擎首次运行时会再次出现 Windows 防火墙提示。',
    );
    if (!confirmed) return;
    setState(() => _firewallBusy = true);
    try {
      await WindowsFirewallRuleService.instance.unregister(
        BtEngineClient.bundledExecutablePath(),
      );
      await _refreshFirewallStatus();
      if (mounted) await BtInfobar.success(context, '防火墙规则已移除');
    } catch (error) {
      if (mounted) await BtInfobar.warn(context, '移除防火墙规则失败：$error');
    } finally {
      if (mounted) setState(() => _firewallBusy = false);
    }
  }

  String _firewallStatusText() {
    switch (_firewallStatus) {
      case EngineFirewallRuleStatus.registered:
        return '已注册：首次运行不再弹出防火墙提示';
      case EngineFirewallRuleStatus.pathMismatch:
        return '已注册但指向旧路径，请重新注册';
      case EngineFirewallRuleStatus.notRegistered:
        return '未注册：首次运行会弹出系统防火墙提示';
      case EngineFirewallRuleStatus.unsupported:
        return '无法检测防火墙规则状态';
      case null:
        return '正在检测防火墙规则…';
    }
  }

  @override
  void dispose() {
    _sourceController.dispose();
    _manualTrackerController.dispose();
    super.dispose();
  }

  /// 构建一行网格设置
  Widget _gridRow(List<Widget> cells) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < cells.length; i++) ...[
          if (i > 0) SizedBox(width: 12),
          Expanded(child: cells[i]),
        ],
      ],
    );
  }

  /// 构建下载限制（两行三列）
  Widget buildDownloadLimits() {
    Widget cell({
      required String title,
      required String description,
      required Widget control,
    }) {
      return _SettingGridCell(
        title: title,
        description: description,
        control: control,
      );
    }

    Widget numberCell({
      required String title,
      required String description,
      required int value,
      required int min,
      required int max,
      required ValueChanged<int> onChanged,
    }) {
      return cell(
        title: title,
        description: description,
        control: NumberBox<int>(
          value: value,
          min: min,
          max: max,
          mode: SpinButtonPlacementMode.none,
          onChanged: _saving
              ? null
              : (next) {
                  if (next != null) onChanged(next);
                },
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _gridRow([
          numberCell(
            title: '同时下载任务数',
            description: '并行下载任务数上限',
            value: _config.activeDownloads,
            min: 1,
            max: 64,
            onChanged: (value) => setState(
              () => _config = _config.copyWith(activeDownloads: value),
            ),
          ),
          numberCell(
            title: '下载限速（KiB/s）',
            description: '0 表示不限速',
            value: _config.downloadRateLimitKiB,
            min: 0,
            max: _maxRateLimitKiB,
            onChanged: (value) => setState(
              () => _config = _config.copyWith(downloadRateLimit: value * 1024),
            ),
          ),
          numberCell(
            title: '上传限速（KiB/s）',
            description: '0 表示不限速',
            value: _config.uploadRateLimitKiB,
            min: 0,
            max: _maxRateLimitKiB,
            onChanged: (value) => setState(
              () => _config = _config.copyWith(uploadRateLimit: value * 1024),
            ),
          ),
        ]),
        SizedBox(height: 12),
        _gridRow([
          numberCell(
            title: '全局连接数',
            description: '引擎最大连接数',
            value: _config.connectionsLimit,
            min: 1,
            max: 10000,
            onChanged: (value) => setState(() {
              _config = _config.copyWith(
                connectionsLimit: value,
                connectionsPerTask: min(_config.connectionsPerTask, value),
              );
            }),
          ),
          numberCell(
            title: '单任务连接数',
            description: '单任务最大连接数',
            value: _config.connectionsPerTask,
            min: 1,
            max: _config.connectionsLimit,
            onChanged: (value) => setState(
              () => _config = _config.copyWith(connectionsPerTask: value),
            ),
          ),
          numberCell(
            title: '磁力元数据超时（秒）',
            description: '超时未获取元数据则标记失败',
            value: _config.metadataTimeoutSeconds,
            min: 1,
            max: 86400,
            onChanged: (value) => setState(
              () => _config = _config.copyWith(metadataTimeoutSeconds: value),
            ),
          ),
        ]),
      ],
    );
  }

  /// 构建做种设置（三列）
  Widget buildSeedingSettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const InfoBar(
          title: Text('Tracker 与做种隐私提示'),
          content: Text(
            '补充 Tracker 和 BT Peer 会获知任务 info-hash 与你的 IP。'
            '公共补充 Tracker 不会应用到私有种子。',
          ),
          severity: InfoBarSeverity.warning,
        ),
        SizedBox(height: 12),
        _gridRow([
          _SettingGridCell(
            title: '下载完成后继续做种',
            description: '分享率或时间任一先达即停',
            control: ToggleSwitch(
              checked: _config.seedingEnabled,
              onChanged: _saving
                  ? null
                  : (value) => setState(
                      () => _config = _config.copyWith(seedingEnabled: value),
                    ),
            ),
          ),
          _SettingGridCell(
            title: '做种分享率',
            description: '0 表示不使用分享率条件',
            control: NumberBox<double>(
              value: _config.seedRatioLimit,
              min: 0,
              max: 100,
              smallChange: 0.1,
              mode: SpinButtonPlacementMode.none,
              onChanged: _saving
                  ? null
                  : (value) {
                      if (value != null) {
                        setState(
                          () =>
                              _config = _config.copyWith(seedRatioLimit: value),
                        );
                      }
                    },
            ),
          ),
          _SettingGridCell(
            title: '做种时间（分钟）',
            description: '0 表示不使用时间条件',
            control: NumberBox<int>(
              value: _config.seedTimeLimitMinutes,
              min: 0,
              max: 525600,
              mode: SpinButtonPlacementMode.none,
              onChanged: _saving
                  ? null
                  : (value) {
                      if (value != null) {
                        setState(
                          () => _config = _config.copyWith(
                            seedTimeLimitMinutes: value,
                          ),
                        );
                      }
                    },
            ),
          ),
        ]),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return BTSettingSection(
      icon: FluentIcons.download,
      title: '下载引擎',
      subtitle: '引擎开关、限速与 Tracker 设置',
      initiallyExpanded: false,
      children: [
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: ProgressRing()),
          )
        else if (_loadError != null)
          InfoBar(
            title: const Text('无法读取下载设置'),
            content: Text(_loadError!),
            severity: InfoBarSeverity.error,
          )
        else ...[
          ListTile(
            title: const Text('启用下载引擎'),
            subtitle: const Text('默认关闭，需手动开启；开启后应用启动时会自动运行下载引擎'),
            trailing: ToggleSwitch(
              checked: _config.engineEnabled,
              onChanged: _saving ? null : _toggleEngine,
            ),
          ),
          const BTSettingDivider(),
          const BTSettingGroupTitle('Windows 防火墙规则'),
          const BTSettingHint(
            icon: FluentIcons.shield,
            message:
                '下载引擎监听网络端口，需入站放行才能接收 Peer 连接。'
                '开启下载引擎时会自动注册入站允许规则；规则未注册或指向旧路径'
                '（如引擎更新后）时可手动重新注册，也可以直接在新弹窗中点击“允许访问”。'
                '注册与移除都需要管理员授权。',
          ),
          SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  _firewallStatusText(),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(width: 8),
              if (_firewallStatus == EngineFirewallRuleStatus.registered ||
                  _firewallStatus == EngineFirewallRuleStatus.pathMismatch)
                Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: Button(
                    onPressed: _firewallBusy ? null : _unregisterFirewallRule,
                    child: const Text('移除规则'),
                  ),
                ),
              FilledButton(
                onPressed: _firewallBusy ? null : _registerFirewallRule,
                child: _firewallBusy
                    ? const SizedBox.square(
                        dimension: 16,
                        child: ProgressRing(strokeWidth: 2),
                      )
                    : const Text('注册规则'),
              ),
            ],
          ),
          const BTSettingDivider(),
          const BTSettingGroupTitle('下载限制'),
          buildDownloadLimits(),
          const BTSettingDivider(),
          const BTSettingGroupTitle('做种设置'),
          buildSeedingSettings(),
          const BTSettingDivider(),
          const BTSettingGroupTitle('Tracker 列表来源（每行一个 HTTP/HTTPS URL，最多 8 个）'),
          TextBox(
            controller: _sourceController,
            minLines: 2,
            maxLines: 4,
            enabled: !_saving && !_refreshingTrackers,
            placeholder: 'https://example.com/trackers.txt',
          ),
          SizedBox(height: 12),
          const BTSettingGroupTitle('手工 Tracker（换行或逗号分隔）'),
          TextBox(
            controller: _manualTrackerController,
            minLines: 3,
            maxLines: 6,
            enabled: !_saving && !_refreshingTrackers,
            placeholder: 'udp://tracker.example:6969/announce',
          ),
          SizedBox(height: 8),
          Checkbox(
            checked: _trackerConfig.autoUpdate,
            onChanged: _saving || _refreshingTrackers
                ? null
                : (value) => setState(
                    () => _trackerConfig = _trackerConfig.copyWith(
                      autoUpdate: value ?? false,
                    ),
                  ),
            content: const Text('距上次成功更新满 24 小时后自动刷新'),
          ),
          SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  _trackerStatusText(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Button(
                onPressed: _saving || _refreshingTrackers
                    ? null
                    : _refreshTrackerList,
                child: _refreshingTrackers
                    ? const SizedBox.square(
                        dimension: 16,
                        child: ProgressRing(strokeWidth: 2),
                      )
                    : const Text('立即刷新'),
              ),
            ],
          ),
          SizedBox(height: 12),
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
      ],
    );
  }

  String _trackerStatusText() {
    var success = _trackerConfig.lastUpdateSuccessAt;
    var prefix = success == null
        ? '尚未成功更新'
        : '上次成功：${success.toLocal().toString().substring(0, 19)}';
    var count = TrackerHive().effectiveTrackers.length;
    var error = _trackerConfig.lastUpdateError;
    return '$prefix · 当前 $count 条${error == null ? '' : ' · $error'}';
  }
}

/// 设置网格单元（标题 + 控件，说明文字悬停显示）
class _SettingGridCell extends StatefulWidget {
  /// 标题
  final String title;

  /// 说明文字
  final String description;

  /// 控件
  final Widget control;

  /// 构造函数
  const _SettingGridCell({
    required this.title,
    required this.description,
    required this.control,
  });

  @override
  State<_SettingGridCell> createState() => _SettingGridCellState();
}

class _SettingGridCellState extends State<_SettingGridCell> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    var accent = FluentTheme.of(context).accentColor;
    var isDark = FluentTheme.of(context).brightness == Brightness.dark;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Tooltip(
        message: widget.description,
        child: AnimatedContainer(
          duration: BTTheme.animationDurationFast,
          curve: BTTheme.animationCurve,
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _hovered
                ? accent.withValues(alpha: 0.05)
                : (isDark ? const Color(0xFF2B2B2B) : const Color(0xFFF7F7F7)),
            borderRadius: BTRadius.mediumBR,
            border: Border.all(
              color: _hovered
                  ? accent.withValues(alpha: 0.4)
                  : BTColors.divider(context),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: BTTypography.bodyStrong(
                    context,
                  ).copyWith(fontSize: 13),
                ),
              ),
              SizedBox(width: 8),
              SizedBox(
                width: 88,
                height: 32,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: widget.control,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
