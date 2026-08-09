part of '../rb_pw_bmf.dart';

class _BmfConfigDraft {
  final String title;
  final String rss;
  final String download;
  final bool autoUpdate;

  const _BmfConfigDraft({
    required this.title,
    required this.rss,
    required this.download,
    required this.autoUpdate,
  });
}

class _BmfConfigDialog extends StatefulWidget {
  final AppBmfModel bmf;

  const _BmfConfigDialog({required this.bmf});

  @override
  State<_BmfConfigDialog> createState() => _BmfConfigDialogState();
}

class _BmfConfigDialogState extends State<_BmfConfigDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _rssController;
  late final TextEditingController _downloadController;
  late bool _autoUpdate;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.bmf.title ?? '');
    _rssController = TextEditingController(text: widget.bmf.rss ?? '');
    _downloadController = TextEditingController(
      text: widget.bmf.download ?? '',
    );
    _autoUpdate = widget.bmf.autoUpdate;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _rssController.dispose();
    _downloadController.dispose();
    super.dispose();
  }

  void _submit() {
    Navigator.of(context).pop(
      _BmfConfigDraft(
        title: _titleController.text,
        rss: _rssController.text,
        download: _downloadController.text,
        autoUpdate: _autoUpdate,
      ),
    );
  }

  Future<void> _refreshNow() async {
    if (_refreshing) return;
    if (widget.bmf.rss == null || widget.bmf.rss!.isEmpty) {
      await BtInfobar.error(context, '请先配置 RSS');
      return;
    }

    setState(() => _refreshing = true);
    var result = await BmfRssService.instance.refreshBmf(widget.bmf);
    if (!mounted) return;
    setState(() => _refreshing = false);
    if (result) {
      await BtInfobar.success(context, 'RSS 刷新成功');
    } else {
      await BtInfobar.error(context, 'RSS 刷新失败');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ContentDialog(
      constraints: BoxConstraints(maxWidth: 620),
      title: Row(
        children: [
          Icon(FluentIcons.link, size: 18),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              '编辑 ${widget.bmf.title ?? widget.bmf.subject}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLabel(context, '显示标题'),
            TextBox(controller: _titleController, placeholder: '番剧标题'),
            SizedBox(height: 14),
            _buildLabel(context, 'RSS 订阅'),
            TextBox(
              controller: _rssController,
              placeholder: 'Mikan RSS 或其他兼容订阅地址',
            ),
            SizedBox(height: 14),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('RSS 自动更新'),
              subtitle: Text(
                _autoUpdate ? '应用运行时会按计划自动刷新 RSS' : '已关闭自动刷新，可使用刷新按钮手动更新',
              ),
              trailing: ToggleSwitch(
                checked: _autoUpdate,
                onChanged: (value) => setState(() => _autoUpdate = value),
              ),
            ),
            SizedBox(height: 6),
            _buildLabel(context, '本地目录'),
            TextBox(
              controller: _downloadController,
              placeholder: '内置下载引擎保存文件的目标目录',
              suffix: Tooltip(
                message: '选择目录',
                child: IconButton(
                  icon: BtIcon(FluentIcons.folder_open, size: 14),
                  onPressed: () async {
                    var directory = await getDirectoryPath();
                    if (directory == null || !mounted) return;
                    setState(() => _downloadController.text = directory);
                  },
                ),
              ),
            ),
            SizedBox(height: 10),
            Text(
              '应用会把 torrent 与该目录交给内置下载引擎；任务可在下载管理页查看。',
              style: BTTypography.caption(context),
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
          onPressed: _refreshing ? null : _refreshNow,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(FluentIcons.refresh, size: 13),
              SizedBox(width: 6),
              Text(_refreshing ? '刷新中…' : '刷新 RSS'),
            ],
          ),
        ),
        FilledButton(onPressed: _submit, child: const Text('保存关联')),
      ],
    );
  }

  Widget _buildLabel(BuildContext context, String label) {
    return Padding(
      padding: EdgeInsets.only(bottom: 6),
      child: Text(label, style: BTTypography.bodyStrong(context)),
    );
  }
}
