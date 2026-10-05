part of '../rss_bmf_workspace.dart';

class _BmfConfigDraft {
  final String title;
  final String download;
  final List<AppSubscriptionModel> subscriptions;
  const _BmfConfigDraft(this.title, this.download, this.subscriptions);
}

class _SubscriptionEditor {
  final AppSubscriptionModel original;
  final TextEditingController url;
  bool autoUpdate;
  _SubscriptionEditor(this.original)
    : url = TextEditingController(text: original.url),
      autoUpdate = original.autoUpdate;
}

class _BmfConfigDialog extends ConsumerStatefulWidget {
  final AppBmfModel bmf;
  const _BmfConfigDialog({required this.bmf});
  @override
  ConsumerState<_BmfConfigDialog> createState() => _BmfConfigDialogState();
}

class _BmfConfigDialogState extends ConsumerState<_BmfConfigDialog> {
  late final TextEditingController _title;
  late final TextEditingController _download;
  late final List<_SubscriptionEditor> _subscriptions;
  final List<_SubscriptionEditor> _removed = [];
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.bmf.title ?? '');
    _download = TextEditingController(text: widget.bmf.download ?? '');
    _subscriptions = widget.bmf.subscriptions
        .map(_SubscriptionEditor.new)
        .toList();
  }

  @override
  void dispose() {
    _title.dispose();
    _download.dispose();
    for (var editor in [..._subscriptions, ..._removed]) {
      editor.url.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    var desired = _subscriptions
        .map(
          (editor) => editor.original.copyWith(
            url: editor.url.text.trim(),
            autoUpdate: editor.autoUpdate,
          ),
        )
        .toList();
    if (desired.any((s) => s.url.isEmpty || (s.id < 0 && !s.canRefresh))) {
      await BtInfobar.error(context, '请填写有效的 HTTP 或 HTTPS RSS 地址');
      return;
    }
    if (desired.map((s) => s.feedKey).toSet().length != desired.length) {
      await BtInfobar.error(context, '同一番剧不能重复添加相同订阅');
      return;
    }
    if (mounted) {
      Navigator.of(
        context,
      ).pop(_BmfConfigDraft(_title.text, _download.text, desired));
    }
  }

  void _add(String url) {
    setState(
      () => _subscriptions.add(
        _SubscriptionEditor(
          AppSubscriptionModel.forUrl(url, bmfId: widget.bmf.id),
        ),
      ),
    );
  }

  Future<void> _searchRss() async {
    var behavior = ref.read(appStoreProvider).rssSelectionBehavior;
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      dismissWithEsc: true,
      builder: (_) => SubjectRssSearchDialog(
        subjectId: widget.bmf.subject,
        title: _title.text.trim(),
        currentRss: _subscriptions.firstOrNull?.url.text,
        selectionBehavior: behavior,
        selectOnly: true,
        onSubscribe: (_, rss) async {
          if (!mounted) return false;
          var current = widget.bmf.copyWith(
            subscriptions: [
              for (var editor in _subscriptions)
                editor.original.copyWith(
                  url: editor.url.text.trim(),
                  autoUpdate: editor.autoUpdate,
                ),
            ],
          );
          var selected = current.withSelectedRss(rss, behavior: behavior);
          setState(() {
            _removed.addAll(_subscriptions);
            _subscriptions
              ..clear()
              ..addAll(selected.subscriptions.map(_SubscriptionEditor.new));
          });
          return true;
        },
      ),
    );
  }

  Future<void> _refreshNow() async {
    setState(() => _refreshing = true);
    try {
      var result = await ref.read(bmfRepositoryProvider).refreshRss(widget.bmf);
      if (mounted) {
        if (result) {
          await BtInfobar.success(context, '已保存的 RSS 刷新成功');
        } else {
          await BtInfobar.error(context, 'RSS 刷新失败或需要核对配置');
        }
      }
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) => ContentDialog(
    constraints: const BoxConstraints(maxWidth: 720),
    title: Text('编辑 ${widget.bmf.title ?? widget.bmf.subject}'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('显示标题'),
          const SizedBox(height: 6),
          TextBox(controller: _title, placeholder: '番剧标题'),
          const SizedBox(height: 16),
          Row(
            children: [
              const Expanded(child: Text('RSS 订阅')),
              Button(onPressed: () => _add(''), child: const Text('添加地址')),
              const SizedBox(width: 8),
              Button(onPressed: _searchRss, child: const Text('搜索 RSS')),
            ],
          ),
          for (var editor in _subscriptions)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          editor.original.status == 'needsReview'
                              ? '待核对 · ${editor.original.provider}'
                              : editor.original.provider,
                        ),
                      ),
                      BmfAutoUpdateButton(
                        enabled: editor.autoUpdate,
                        onChanged: (value) =>
                            setState(() => editor.autoUpdate = value),
                      ),
                      IconButton(
                        icon: const Icon(FluentIcons.delete, size: 14),
                        onPressed: () => setState(() {
                          _subscriptions.remove(editor);
                          _removed.add(editor);
                        }),
                      ),
                    ],
                  ),
                  TextBox(controller: editor.url, placeholder: '完整 RSS 订阅地址'),
                ],
              ),
            ),
          const SizedBox(height: 10),
          const Text('更换或删除地址时，未处理记录会保存在「待核对」中。'),
          const SizedBox(height: 16),
          const Text('本地目录'),
          const SizedBox(height: 6),
          TextBox(
            controller: _download,
            placeholder: '内置下载引擎保存文件的目标目录',
            suffix: IconButton(
              icon: BtIcon(FluentIcons.folder_open, size: 14),
              onPressed: () async {
                var directory = await getDirectoryPath();
                if (directory != null && mounted) {
                  setState(() => _download.text = directory);
                }
              },
            ),
          ),
        ],
      ),
    ),
    actions: [
      Button(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('取消'),
      ),
      Button(
        onPressed: _refreshing || widget.bmf.subscriptions.isEmpty
            ? null
            : _refreshNow,
        child: Text(_refreshing ? '刷新中…' : '刷新已保存的 RSS'),
      ),
      FilledButton(onPressed: _submit, child: const Text('保存关联')),
    ],
  );
}
