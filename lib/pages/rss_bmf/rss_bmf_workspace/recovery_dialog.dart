part of '../rss_bmf_workspace.dart';

class _RecoveryDialog extends StatefulWidget {
  const _RecoveryDialog();
  @override
  State<_RecoveryDialog> createState() => _RecoveryDialogState();
}

class _RecoveryDialogState extends State<_RecoveryDialog> {
  final Map<int, int> _targets = {};
  late Future<(List<MigrationRecoveryRow>, List<AppBmfModel>)> _load;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _load = Future(
      () async => (
        await appSubscriptionStorage.unresolvedRecovery(),
        await BtsAppBmf().readAll(),
      ),
    );
  }

  Future<void> _resolve(int id, {bool discard = false}) async {
    if (discard &&
        !await showConfirm(
          context,
          title: '放弃旧状态',
          content: '确认放弃这条记录的旧状态？原始记录仍会保留。',
        )) {
      return;
    }
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      await appSubscriptionStorage.resolveRecovery(
        id,
        subscriptionId: _targets[id],
        discard: discard,
      );
      if (mounted) setState(_reload);
    } catch (_) {
      if (mounted) await BtInfobar.error(context, '无法分配这条旧状态。请核对原始记录，或明确放弃。');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ContentDialog(
    constraints: const BoxConstraints(maxWidth: 760),
    title: const Text('待核对记录'),
    content: FutureBuilder(
      future: _load,
      builder: (context, snapshot) {
        if (snapshot.hasError) return const Text('读取失败');
        if (!snapshot.hasData) return const Center(child: ProgressRing());
        var (records, parents) = snapshot.data!;
        if (records.isEmpty) return const Text('没有待核对记录');
        return SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var record in records)
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${record.kind} · ${record.legacyKey}'),
                      const SizedBox(height: 6),
                      SelectableText(
                        const JsonEncoder.withIndent(
                          '  ',
                        ).convert(jsonDecode(record.payload)),
                      ),
                      const SizedBox(height: 8),
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
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Button(
                            onPressed: _busy || !_targets.containsKey(record.id)
                                ? null
                                : () => _resolve(record.id),
                            child: const Text('分配旧状态'),
                          ),
                          const SizedBox(width: 8),
                          Button(
                            onPressed: _busy
                                ? null
                                : () => _resolve(record.id, discard: true),
                            child: const Text('放弃旧状态'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    ),
    actions: [
      Button(
        onPressed: _busy ? null : () => Navigator.of(context).pop(),
        child: const Text('关闭'),
      ),
    ],
  );
}
