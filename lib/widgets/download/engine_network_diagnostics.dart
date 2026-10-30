// Dart imports:
import 'dart:async';

// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../core/services/bt_engine_client.dart';
import '../../store/bt_download_store.dart';

class EngineNetworkDiagnostics extends StatelessWidget {
  const EngineNetworkDiagnostics({super.key});

  @override
  Widget build(BuildContext context) => ListTile(
    title: const Text('网络诊断'),
    subtitle: const Text('查看监听、DHT、发现与端口映射状态'),
    trailing: Tooltip(
      message: '打开网络诊断',
      child: IconButton(
        icon: const Icon(FluentIcons.info, size: 16),
        onPressed: () => unawaited(
          showDialog<void>(
            context: context,
            barrierDismissible: true,
            builder: (_) => const _EngineNetworkDiagnosticsDialog(),
          ),
        ),
      ),
    ),
  );
}

class _EngineNetworkDiagnosticsDialog extends ConsumerStatefulWidget {
  const _EngineNetworkDiagnosticsDialog();

  @override
  ConsumerState<_EngineNetworkDiagnosticsDialog> createState() =>
      _EngineNetworkDiagnosticsDialogState();
}

class _EngineNetworkDiagnosticsDialogState
    extends ConsumerState<_EngineNetworkDiagnosticsDialog> {
  BtEngineNetworkStatus? _network;
  String? _error;
  bool _loading = false;
  int _request = 0;

  String _listenerAddress(String address) =>
      address.contains(':') ? '[$address]' : address;

  @override
  void initState() {
    super.initState();
    unawaited(Future.microtask(_refresh));
  }

  Future<void> _refresh() async {
    if (!mounted ||
        _loading ||
        ref.read(btDownloadStoreProvider).engineState !=
            BtEngineClientState.ready) {
      return;
    }
    var request = ++_request;
    setState(() => _loading = true);
    try {
      var result = await ref
          .read(btDownloadStoreProvider.notifier)
          .engineNetworkStatus();
      if (!mounted || request != _request) return;
      setState(() {
        _network = result;
        _error = null;
      });
    } catch (error) {
      if (mounted && request == _request) {
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted && request == _request) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    var ready = ref.watch(
      btDownloadStoreProvider.select(
        (state) => state.engineState == BtEngineClientState.ready,
      ),
    );
    ref.listen(btDownloadStoreProvider.select((state) => state.engineState), (
      _,
      next,
    ) {
      ++_request;
      setState(() {
        _network = null;
        _error = null;
        _loading = false;
      });
      if (next == BtEngineClientState.ready) unawaited(_refresh());
    });
    var network = _network;
    var listening = network?.listening == true
        ? '已监听，端口 ${network!.listenPort}'
        : '未监听';
    var dhtNodes = network?.dhtSampled == true
        ? network!.dhtNodes?.toString() ?? '未采样'
        : '未采样';
    return ContentDialog(
      constraints: BoxConstraints(
        maxWidth: 760,
        maxHeight: MediaQuery.sizeOf(context).height * .85,
      ),
      title: Row(
        children: [
          const Expanded(child: Text('网络诊断')),
          Tooltip(
            message: !ready
                ? '开启下载引擎后可查询'
                : _loading
                ? '正在查询网络状态'
                : '刷新网络状态',
            child: IconButton(
              icon: _loading
                  ? const SizedBox.square(
                      dimension: 14,
                      child: ProgressRing(strokeWidth: 2),
                    )
                  : const Icon(FluentIcons.refresh, size: 14),
              onPressed: ready && !_loading
                  ? () => unawaited(_refresh())
                  : null,
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!ready)
              const Text('下载引擎未就绪')
            else if (network == null && _error == null)
              Text(_loading ? '正在查询网络状态…' : '点击刷新查看当前网络状态'),
            if (_error != null) Text('查询失败：$_error'),
            if (ready && network != null) ...[
              const Text('以下为查询时的状态；监听成功不代表已从公网验证入站连通。'),
              const SizedBox(height: 12),
              SelectableText(
                '监听：$listening\n'
                'DHT：${network.dhtEnabled ? '启用' : '关闭'} / '
                '${network.dhtRunning ? '运行中' : '未运行'} / 节点 $dhtNodes\n'
                '本地发现：${network.lsdEnabled ? '启用' : '关闭'}\n'
                'UPnP：${network.upnpEnabled ? '启用' : '关闭'} · '
                'NAT-PMP：${network.natPmpEnabled ? '启用' : '关闭'}',
              ),
              const SizedBox(height: 12),
              for (var listener in network.listeners)
                SelectableText(
                  '最近监听结果：${listener.socketType} · '
                  '${_listenerAddress(listener.address)}'
                  ':${listener.port} · '
                  '${listener.state == 'listening' ? '成功' : listener.error}',
                ),
              const SizedBox(height: 12),
              if (network.portMappings.isEmpty)
                const Text('端口映射：尚无结果（关闭时不会发起映射）'),
              for (var mapping in network.portMappings)
                SelectableText(
                  '${mapping.transport == 'upnp' ? 'UPnP' : 'NAT-PMP'} · '
                  '${mapping.address}：'
                  '${mapping.state == 'mapped' ? '已映射' : mapping.error}'
                  '${mapping.externalPort == null ? '' : '，外部端口 '}'
                  '${mapping.externalPort ?? ''}',
                ),
            ],
          ],
        ),
      ),
      actions: [
        Button(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
      ],
    );
  }
}
