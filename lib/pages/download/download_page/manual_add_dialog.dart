part of '../download_page.dart';

class _ManualDownloadDraft {
  const _ManualDownloadDraft({
    required this.uri,
    required this.savePath,
    this.displayName,
  });

  final String uri;
  final String savePath;
  final String? displayName;
}

class _ManualDownloadDialog extends StatefulWidget {
  const _ManualDownloadDialog();

  @override
  State<_ManualDownloadDialog> createState() => _ManualDownloadDialogState();
}

class _ManualDownloadDialogState extends State<_ManualDownloadDialog> {
  final _uriController = TextEditingController();
  final _nameController = TextEditingController();
  final _savePathController = TextEditingController();
  String? _errorText;

  @override
  void dispose() {
    _uriController.dispose();
    _nameController.dispose();
    _savePathController.dispose();
    super.dispose();
  }

  Future<void> _pickDirectory() async {
    var directory = await getDirectoryPath();
    if (directory == null || !mounted) return;
    setState(() => _savePathController.text = directory);
  }

  void _submit() {
    var uri = _uriController.text.trim();
    var savePath = _savePathController.text.trim();
    var errorText = _validateManualDownloadInput(uri: uri, savePath: savePath);
    if (errorText != null) {
      setState(() => _errorText = errorText);
      return;
    }

    var displayName = _nameController.text.trim();
    Navigator.of(context).pop(
      _ManualDownloadDraft(
        uri: uri,
        savePath: savePath,
        displayName: displayName.isEmpty ? null : displayName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ContentDialog(
      constraints: BoxConstraints(maxWidth: 620),
      title: Row(
        children: [
          Icon(FluentIcons.download, size: 18),
          SizedBox(width: 8),
          const Text('添加下载任务'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLabel(context, '下载链接'),
            TextBox(
              controller: _uriController,
              autofocus: true,
              minLines: 2,
              maxLines: 4,
              placeholder: '支持 HTTP(S)、magnet: 或远程 .torrent 链接',
            ),
            SizedBox(height: 14),
            _buildLabel(context, '任务名称（可选）'),
            TextBox(controller: _nameController, placeholder: '留空时使用文件名或种子名称'),
            SizedBox(height: 14),
            _buildLabel(context, '保存位置'),
            TextBox(
              controller: _savePathController,
              placeholder: '选择或输入下载文件保存目录',
              suffix: Tooltip(
                message: '选择目录',
                child: IconButton(
                  icon: const Icon(FluentIcons.folder_open, size: 14),
                  onPressed: _pickDirectory,
                ),
              ),
            ),
            SizedBox(height: 10),
            Text(
              '普通文件直链由 HTTP 引擎下载；远程 .torrent 与磁力链接仍使用 BT 引擎。',
              style: BTTypography.caption(context),
            ),
            if (_errorText != null) ...[
              SizedBox(height: 10),
              Text(
                _errorText!,
                style: BTTypography.caption(
                  context,
                ).copyWith(color: BTColors.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        Button(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(onPressed: _submit, child: const Text('添加任务')),
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

String? _validateManualDownloadInput({
  required String uri,
  required String savePath,
}) {
  if (uri.isEmpty) return '请输入下载链接';
  if (savePath.isEmpty) return '请选择或输入保存位置';

  var parsed = Uri.tryParse(uri);
  if (parsed == null) return '下载链接格式不正确';

  var scheme = parsed.scheme.toLowerCase();
  if (scheme == 'magnet') return null;
  if (scheme != 'http' && scheme != 'https') {
    return '仅支持 HTTP(S)、magnet: 或远程 .torrent 链接';
  }
  if (parsed.host.isEmpty) return '下载链接格式不正确';
  return null;
}

bool _isRemoteTorrentUri(Uri uri) {
  var lastSegment = uri.pathSegments.isEmpty
      ? ''
      : uri.pathSegments.last.toLowerCase();
  return lastSegment.endsWith('.torrent') ||
      uri.queryParameters.containsKey('hash') ||
      uri.queryParameters['type']?.toLowerCase() == 'torrent';
}
