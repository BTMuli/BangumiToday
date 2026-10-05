// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;

// Project imports:
import '../../core/services/download_directory.dart';
import '../../core/services/download_service.dart';
import '../../core/theme/bt_theme.dart';
import '../../store/bt_download_store.dart';
import '../../ui/bt_infobar.dart';

/// Shared by manual downloads and torrent files dropped onto the main window.
Future<void> showManualDownloadDialog(
  BuildContext context,
  WidgetRef ref, {
  List<String> torrentPaths = const [],
}) async {
  try {
    var savePath = await defaultDownloadDirectory();
    if (!context.mounted) return;
    var draft = await showDialog<_ManualDownloadDraft>(
      context: context,
      barrierDismissible: true,
      builder: (_) => _ManualDownloadDialog(
        initialSavePath: savePath ?? '',
        torrentPaths: torrentPaths,
      ),
    );
    if (draft == null || !context.mounted) return;

    var store = ref.read(btDownloadStoreProvider.notifier);
    if (torrentPaths.isNotEmpty) {
      var added = 0;
      var failures = <String>[];
      for (var torrentPath in torrentPaths) {
        if (!context.mounted) return;
        try {
          await store.addTorrentFile(
            torrentPath: torrentPath,
            savePath: draft.savePath,
            displayName: draft.displayName,
            manual: true,
          );
          added++;
        } catch (error) {
          failures.add('${path.basename(torrentPath)}：$error');
        }
      }
      if (!context.mounted) return;
      if (failures.isNotEmpty) {
        await BtInfobar.error(
          context,
          '已添加 $added 个任务，失败 ${failures.length} 个：\n${failures.join('\n')}',
        );
      } else {
        await BtInfobar.success(context, '已添加 $added 个下载任务');
      }
      return;
    }

    var uri = Uri.parse(draft.uri);
    if (uri.scheme.toLowerCase() == 'magnet') {
      await store.addMagnet(
        uri: draft.uri,
        savePath: draft.savePath,
        displayName: draft.displayName,
        manual: true,
      );
    } else if (_isRemoteTorrentUri(uri)) {
      var torrentPath = await BTDownloadTool().downloadRssTorrent(
        draft.uri,
        draft.displayName ?? '手动添加',
        context: context,
      );
      if (torrentPath.isEmpty || !context.mounted) return;
      await store.addTorrentFile(
        torrentPath: torrentPath,
        savePath: draft.savePath,
        displayName: draft.displayName,
        manual: true,
      );
    } else {
      await store.addHttp(
        url: draft.uri,
        savePath: draft.savePath,
        displayName: draft.displayName,
        manual: true,
      );
    }
    if (context.mounted) await BtInfobar.success(context, '下载任务已添加');
  } catch (error) {
    if (context.mounted) await BtInfobar.error(context, error.toString());
  }
}

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
  const _ManualDownloadDialog({
    required this.initialSavePath,
    required this.torrentPaths,
  });

  final String initialSavePath;
  final List<String> torrentPaths;

  @override
  State<_ManualDownloadDialog> createState() => _ManualDownloadDialogState();
}

class _ManualDownloadDialogState extends State<_ManualDownloadDialog> {
  final _uriController = TextEditingController();
  final _nameController = TextEditingController();
  late final TextEditingController _savePathController;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _savePathController = TextEditingController(text: widget.initialSavePath);
  }

  @override
  void dispose() {
    _uriController.dispose();
    _nameController.dispose();
    _savePathController.dispose();
    super.dispose();
  }

  Future<void> _pickDirectory() async {
    var directory = await pickDownloadDirectory(
      currentPath: _savePathController.text,
    );
    if (directory == null || !mounted) return;
    setState(() => _savePathController.text = directory);
  }

  void _submit() {
    var uri = _uriController.text.trim();
    var savePath = _savePathController.text.trim();
    var errorText = widget.torrentPaths.isEmpty
        ? _validateManualDownloadInput(uri: uri, savePath: savePath)
        : savePath.isEmpty
        ? '请选择或输入保存位置'
        : null;
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
            if (widget.torrentPaths.isEmpty) ...[
              _buildLabel(context, '下载链接'),
              TextBox(
                controller: _uriController,
                autofocus: true,
                minLines: 2,
                maxLines: 4,
                placeholder: '支持 HTTP(S)、magnet: 或远程 .torrent 链接',
              ),
            ] else ...[
              _buildLabel(context, '种子文件（${widget.torrentPaths.length} 个）'),
              for (var torrentPath in widget.torrentPaths)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Tooltip(
                    message: torrentPath,
                    child: Text(
                      path.basename(torrentPath),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
            ],
            const SizedBox(height: 14),
            if (widget.torrentPaths.length <= 1) ...[
              _buildLabel(context, '任务名称（可选）'),
              TextBox(
                controller: _nameController,
                placeholder: '留空时使用文件名或种子名称',
              ),
              const SizedBox(height: 14),
            ],
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
              widget.torrentPaths.isEmpty
                  ? '普通文件直链由 HTTP 引擎下载；远程 .torrent 与磁力链接仍使用 BT 引擎。'
                  : '种子内的文件将保存到所选目录。',
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
