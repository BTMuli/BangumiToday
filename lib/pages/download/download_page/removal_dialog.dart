part of '../download_page.dart';

enum _DownloadRemoval { keepFiles, deleteFiles }

Future<_DownloadRemoval?> _showDownloadRemovalDialog(
  BuildContext context, {
  required List<BtTaskSnapshot> tasks,
}) {
  var taskCount = tasks.length;
  // 已归档的手动种子任务重启后没有 handle，无法安全删除文件。
  var hasArchivedTorrent = tasks.any(
    (task) =>
        task.manual && task.state == 'completed' && task.sourceKind != 'http',
  );
  var deleteFiles = false;
  return showDialog<_DownloadRemoval>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => ContentDialog(
        title: Text(taskCount == 1 ? '删除下载任务？' : '批量删除所选任务？'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              taskCount == 1
                  ? '任务将从列表移除，并停止下载与上传。'
                  : '将删除已选择的 $taskCount 个任务，并停止下载与上传。',
            ),
            const SizedBox(height: 16),
            Checkbox(
              checked: deleteFiles,
              content: const Text('同时删除下载文件'),
              onChanged: hasArchivedTorrent
                  ? null
                  : (value) => setState(() => deleteFiles = value ?? false),
            ),
            if (hasArchivedTorrent) ...[
              const SizedBox(height: 12),
              Text(
                taskCount == 1
                    ? '已归档的手动种子任务不再跟踪文件，只能删除任务记录。'
                    : '所选任务包含已归档的手动种子任务。取消选择这些任务后，可同时删除下载文件。',
                style: BTTypography.caption(context),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              deleteFiles
                  ? '将删除这些任务的下载文件，包括未完成的文件。文件删除后无法恢复。'
                  : '已下载的文件和未完成的文件会保留。',
              style: BTTypography.caption(context).copyWith(
                color: deleteFiles
                    ? BTColors.errorLight(context)
                    : BTColors.textSecondary(context),
              ),
            ),
          ],
        ),
        actions: [
          Button(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(
              deleteFiles
                  ? _DownloadRemoval.deleteFiles
                  : _DownloadRemoval.keepFiles,
            ),
            child: Text(deleteFiles ? '删除任务和文件' : '仅删除任务'),
          ),
        ],
      ),
    ),
  );
}
