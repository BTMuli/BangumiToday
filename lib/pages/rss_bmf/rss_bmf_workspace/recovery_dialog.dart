part of '../rss_bmf_workspace.dart';

class _RecoveryDialog extends StatefulWidget {
  const _RecoveryDialog();
  @override
  State<_RecoveryDialog> createState() => _RecoveryDialogState();
}

class _RecoveryDialogState extends State<_RecoveryDialog> {
  final Map<int, int> _targets = {};
  late Future<(List<MigrationRecoveryRow>, List<AppBmfModel>)> _load;
  int _currentIndex = 0;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _load = Future(() async {
      var records = await appSubscriptionStorage.unresolvedRecovery();
      if (records.isEmpty) {
        if (mounted && ModalRoute.of(context)?.isCurrent == true) {
          Navigator.of(context).pop();
        }
        return (records, <AppBmfModel>[]);
      }
      return (records, await BtsAppBmf().readAll());
    });
  }

  Future<void> _resolve(int id, {bool discard = false}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (discard &&
          !await showConfirm(
            context,
            title: '放弃旧状态',
            content: '确认放弃这条记录的旧状态？原始记录仍会保留。',
          )) {
        return;
      }
      if (!mounted) return;
      await appSubscriptionStorage.resolveRecovery(
        id,
        subscriptionId: _targets[id],
        discard: discard,
      );
      _targets.remove(id);
      if (mounted) setState(_reload);
    } catch (_) {
      if (mounted) await BtInfobar.error(context, '无法分配这条旧状态。请核对原始记录，或明确放弃。');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder(
    future: _load,
    builder: (context, snapshot) {
      var ready =
          snapshot.connectionState == ConnectionState.done &&
          snapshot.hasData &&
          !snapshot.hasError;
      var records = ready ? snapshot.data!.$1 : <MigrationRecoveryRow>[];
      var parents = ready ? snapshot.data!.$2 : <AppBmfModel>[];
      var index = records.isEmpty
          ? 0
          : _currentIndex.clamp(0, records.length - 1).toInt();
      var record = records.isEmpty ? null : records[index];
      if (ready && record == null) return const SizedBox.shrink();
      return ContentDialog(
        constraints: BoxConstraints(
          maxWidth: 760,
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                record == null
                    ? '待核对记录'
                    : '待核对记录（${index + 1}/${records.length}）',
              ),
            ),
            if (record != null) ...[
              Tooltip(
                message: '上一条',
                child: IconButton(
                  icon: const Icon(FluentIcons.chevron_left),
                  onPressed: _busy || index == 0
                      ? null
                      : () => setState(() => _currentIndex = index - 1),
                ),
              ),
              const SizedBox(width: 8),
              Tooltip(
                message: '下一条',
                child: IconButton(
                  icon: const Icon(FluentIcons.chevron_right),
                  onPressed: _busy || index == records.length - 1
                      ? null
                      : () => setState(() => _currentIndex = index + 1),
                ),
              ),
            ],
          ],
        ),
        content: snapshot.hasError
            ? const Text('读取失败')
            : !ready
            ? const Center(child: ProgressRing())
            : record == null
            ? const SizedBox.shrink()
            : Column(
                key: ValueKey(record.id),
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${record.kind} · ${record.legacyKey}'),
                  const SizedBox(height: 6),
                  Flexible(
                    child: SingleChildScrollView(
                      primary: false,
                      child: SelectableText(
                        const JsonEncoder.withIndent(
                          '  ',
                        ).convert(jsonDecode(record.payload)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  BtSelect<int>(
                    value: _targets[record.id],
                    isExpanded: true,
                    items: [
                      for (var parent in parents)
                        for (var subscription in parent.subscriptions)
                          ComboBoxItem(
                            value: subscription.id,
                            child: Text(
                              '${parent.title ?? parent.subject} · '
                              '${subscription.provider} · '
                              '${subscription.id}',
                            ),
                          ),
                    ],
                    onChanged: _busy
                        ? null
                        : (id) => setState(() {
                            if (id != null) _targets[record.id] = id;
                          }),
                  ),
                ],
              ),
        actions: [
          if (record != null) ...[
            FilledButton(
              onPressed: _busy || !_targets.containsKey(record.id)
                  ? null
                  : () => _resolve(record.id),
              child: const Text('分配旧状态'),
            ),
            Button(
              onPressed: _busy
                  ? null
                  : () => _resolve(record.id, discard: true),
              child: const Text('放弃旧状态'),
            ),
          ],
          Button(
            onPressed: _busy ? null : () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
      );
    },
  );
}
