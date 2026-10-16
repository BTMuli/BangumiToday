// Dart imports:
import 'dart:async';

// Package imports:
import 'package:fluent_ui/fluent_ui.dart';

// Project imports:
import '../../request/bangumi/bangumi_private_api_probe.dart';

Future<bool> showBangumiPrivateApiTestDialog(
  BuildContext context, {
  required String apiBaseUrl,
}) async =>
    await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (_) => _BangumiPrivateApiTestDialog(apiBaseUrl: apiBaseUrl),
    ) ??
    false;

class _BangumiPrivateApiTestDialog extends StatefulWidget {
  const _BangumiPrivateApiTestDialog({required this.apiBaseUrl});

  final String apiBaseUrl;

  @override
  State<_BangumiPrivateApiTestDialog> createState() =>
      _BangumiPrivateApiTestDialogState();
}

class _BangumiPrivateApiTestDialogState
    extends State<_BangumiPrivateApiTestDialog> {
  BangumiPrivateApiProbe? _probe;
  StreamSubscription<BangumiPrivateProbeProgress>? _subscription;
  var _progress = BangumiPrivateProbeProgress.initial();

  @override
  void initState() {
    super.initState();
    _start();
  }

  void _start() {
    _probe?.dispose();
    unawaited(_subscription?.cancel());
    var probe = BangumiPrivateApiProbe(widget.apiBaseUrl);
    _probe = probe;
    setState(() => _progress = BangumiPrivateProbeProgress.initial());
    _subscription = probe.run().listen((progress) {
      if (mounted && _probe == probe) setState(() => _progress = progress);
    });
  }

  @override
  void dispose() {
    _probe?.dispose();
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  void _confirm() {
    if (_progress.allPassed) Navigator.of(context).pop(true);
  }

  Widget _result(BangumiPrivateProbeResult result) {
    var statusText = switch (result.status) {
      BangumiPrivateProbeStatus.waiting => '等待测试',
      BangumiPrivateProbeStatus.running => '正在测试',
      BangumiPrivateProbeStatus.passed => '通过',
      BangumiPrivateProbeStatus.failed => '未通过',
    };
    var icon = switch (result.status) {
      BangumiPrivateProbeStatus.passed => FluentIcons.check_mark,
      BangumiPrivateProbeStatus.failed => FluentIcons.error_badge,
      _ => FluentIcons.clock,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: result.status == BangumiPrivateProbeStatus.running
                ? const ProgressRing(strokeWidth: 2)
                : Icon(icon, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${result.endpoint.label} · $statusText'),
                Text(
                  result.endpoint.path,
                  style: FluentTheme.of(context).typography.caption,
                ),
                if (result.completed)
                  Text(
                    '${result.message} · ${result.elapsed!.inMilliseconds} ms',
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ContentDialog(
    title: const Text('P1 接口测试'),
    constraints: const BoxConstraints(maxWidth: 560),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('检测当前镜像的公开 P1 接口，全部通过后可启用新版接口。'),
          const SizedBox(height: 8),
          SelectableText('测试地址：${_probe!.baseUrl}'),
          const SizedBox(height: 16),
          ProgressBar(
            value: _progress.completed / _progress.results.length * 100,
          ),
          const SizedBox(height: 8),
          Text('已完成 ${_progress.completed}/${_progress.results.length} 项测试'),
          const SizedBox(height: 8),
          for (var result in _progress.results) _result(result),
          if (_progress.finished) ...[
            const SizedBox(height: 8),
            InfoBar(
              title: Text(
                _progress.allPassed ? '全部接口测试通过' : '部分接口未通过，无法启用新版接口',
              ),
              severity: _progress.allPassed
                  ? InfoBarSeverity.success
                  : InfoBarSeverity.error,
            ),
          ],
        ],
      ),
    ),
    actions: [
      Button(
        onPressed: _progress.finished ? _start : null,
        child: const Text('重新测试'),
      ),
      Button(
        onPressed: () => Navigator.of(context).pop(false),
        child: const Text('取消'),
      ),
      FilledButton(
        onPressed: _progress.allPassed ? _confirm : null,
        child: const Text('确认启用'),
      ),
    ],
  );
}
