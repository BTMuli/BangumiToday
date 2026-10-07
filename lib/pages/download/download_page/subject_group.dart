part of '../download_page.dart';

class _DownloadSubjectGroup extends ConsumerWidget {
  const _DownloadSubjectGroup({
    required this.group,
    required this.selectionMode,
    required this.selectedIds,
    required this.onToggleSelect,
    required this.onToggleGroupSelect,
  });

  final DownloadTaskGroup group;
  final bool selectionMode;
  final Set<String> selectedIds;
  final ValueChanged<String> onToggleSelect;
  final ValueChanged<Iterable<String>> onToggleGroupSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var tasks = group.tasks;
    var subjectId = group.subjectId!;
    var subject = ref.watch(downloadSubjectDetailsProvider(subjectId)).value;
    var title = subject == null
        ? '条目 #$subjectId'
        : subject.nameCn.isNotEmpty
        ? subject.nameCn
        : subject.name;
    var selectedCount = tasks
        .where((task) => selectedIds.contains(task.id))
        .length;
    var downloadRate = tasks.fold(0, (sum, task) => sum + task.downloadRate);
    var uploadRate = tasks.fold(0, (sum, task) => sum + task.uploadRate);
    var accentColor = FluentTheme.of(context).accentColor;
    var collapsed = ref.watch(
      downloadCollapsedSubjectsProvider.select(
        (subjects) => subjects.contains(subjectId),
      ),
    );
    // 批量选择只临时展开，不改变用户记录的折叠状态。
    var expanded = selectionMode || !collapsed;

    void openSubject() {
      ref
          .read(navStoreProvider.notifier)
          .addNavItemB(subject: subjectId, paneTitle: title, type: '动画');
    }

    void toggleSelection() {
      onToggleGroupSelect(tasks.map((task) => task.id));
    }

    return BTCard(
      padding: EdgeInsets.zero,
      useAcrylic: false,
      useReveal: false,
      shadowLevel: BTShadowLevel.subtle,
      borderColor: selectedCount > 0 ? accentColor : null,
      child: ClipRRect(
        borderRadius: BTRadius.largeBR,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            HoverButton(
              semanticLabel: selectionMode
                  ? '选择 $title 的全部任务'
                  : '$title，${expanded ? '收起任务' : '展开任务'}',
              onPressed: selectionMode
                  ? toggleSelection
                  : () => ref
                        .read(downloadCollapsedSubjectsProvider.notifier)
                        .toggle(subjectId),
              builder: (context, states) => AnimatedContainer(
                duration: BTTheme.animationDurationFast,
                color: states.isHovered || states.isFocused
                    ? accentColor.withValues(alpha: 0.05)
                    : Colors.transparent,
                padding: const EdgeInsets.fromLTRB(20, 14, 14, 14),
                child: Row(
                  children: [
                    if (selectionMode) ...[
                      Checkbox(
                        checked: selectedCount == 0
                            ? false
                            : selectedCount == tasks.length
                            ? true
                            : null,
                        onChanged: (_) => toggleSelection(),
                      ),
                      const SizedBox(width: 4),
                    ],
                    _TaskCover(
                      url: subject?.images.common,
                      state: tasks.first.state,
                      color: accentColor,
                      linked: true,
                      onPressed: selectionMode ? toggleSelection : openSubject,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Tooltip(
                            message: '打开条目：$title',
                            child: HyperlinkButton(
                              onPressed: selectionMode
                                  ? toggleSelection
                                  : openSubject,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                    child: Text(
                                      title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: BTTypography.bodyStrong(context),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Icon(
                                    FluentIcons.open_in_new_window,
                                    size: 11,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 14,
                            runSpacing: 4,
                            children: [
                              Text(
                                '${tasks.length} 个任务',
                                style: BTTypography.caption(context),
                              ),
                              Text(
                                '下载 ${BTFileTool.formatSize(downloadRate)}/s',
                                style: BTTypography.caption(context),
                              ),
                              Text(
                                '上传 ${BTFileTool.formatSize(uploadRate)}/s',
                                style: BTTypography.caption(context),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (!selectionMode) ...[
                      const SizedBox(width: 8),
                      Tooltip(
                        message: expanded ? '收起任务' : '展开任务',
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Icon(
                            expanded
                                ? FluentIcons.chevron_up
                                : FluentIcons.chevron_down,
                            size: 14,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (expanded)
              for (var task in tasks) ...[
                Divider(
                  style: DividerThemeData(
                    horizontalMargin: EdgeInsets.zero,
                    thickness: 1,
                    decoration: BoxDecoration(color: BTColors.divider(context)),
                  ),
                ),
                RepaintBoundary(
                  key: ValueKey(task.id),
                  child: _DownloadTaskTile(
                    taskId: task.id,
                    grouped: true,
                    selectionMode: selectionMode,
                    selected: selectedIds.contains(task.id),
                    onSelect: () => onToggleSelect(task.id),
                  ),
                ),
              ],
          ],
        ),
      ),
    );
  }
}
