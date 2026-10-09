// Package imports:
import 'package:fluent_ui/fluent_ui.dart';

// Project imports:
import '../../core/services/file_service.dart';
import '../../core/theme/bt_theme.dart';
import '../../widgets/common/bt_buttons.dart';

class StorageCleanupOption<T> {
  const StorageCleanupOption({
    required this.value,
    required this.title,
    required this.description,
    required this.bytes,
    this.enabled = true,
  });

  final T value;
  final String title;
  final String description;
  final int? bytes;
  final bool enabled;
}

class StorageCleanupGrouping<T> {
  const StorageCleanupGrouping({
    required this.label,
    required this.groupBy,
    required this.itemTitle,
    this.compareGroups,
    this.compareItems,
    this.groupAction,
    this.itemAction,
    this.pinHeaders = false,
  });

  final String label;
  final String Function(T value) groupBy;
  final String Function(T value) itemTitle;
  final Comparator<String>? compareGroups;
  final Comparator<T>? compareItems;
  final Widget? Function(String group, List<T> values)? groupAction;
  final Widget? Function(T value)? itemAction;
  final bool pinHeaders;
}

Future<Set<T>?> showStorageCleanupDialog<T>(
  BuildContext context, {
  required String title,
  required String description,
  required List<StorageCleanupOption<T>> options,
  required Set<T> selected,
  List<StorageCleanupGrouping<T>> groupings = const [],
}) => showDialog<Set<T>>(
  context: context,
  barrierDismissible: true,
  builder: (_) => _StorageCleanupDialog(
    title: title,
    description: description,
    options: options,
    initialSelection: selected,
    groupings: groupings,
  ),
);

class _StorageCleanupDialog<T> extends StatefulWidget {
  const _StorageCleanupDialog({
    required this.title,
    required this.description,
    required this.options,
    required this.initialSelection,
    required this.groupings,
  });

  final String title;
  final String description;
  final List<StorageCleanupOption<T>> options;
  final Set<T> initialSelection;
  final List<StorageCleanupGrouping<T>> groupings;

  @override
  State<_StorageCleanupDialog<T>> createState() =>
      _StorageCleanupDialogState<T>();
}

class _StorageCleanupDialogState<T> extends State<_StorageCleanupDialog<T>> {
  String _sizeLabel(int? bytes) =>
      bytes == null ? '大小未知' : BTFileTool.formatSize(bytes);
  late final _available = {
    for (var option in widget.options)
      if (option.enabled) option.value,
  };
  late final _selected = widget.initialSelection.intersection(_available);
  final _expandedGroups = <(int, String)>{};
  int _groupingIndex = 0;

  Color get _listBackground =>
      FluentTheme.of(context).brightness == Brightness.dark
      ? BTColors.surfacePrimary(context)
      : BTColors.surfaceSecondary(context);

  bool? _checked(Set<T> values) {
    var count = values.where(_selected.contains).length;
    if (count == 0) return false;
    return count == values.length ? true : null;
  }

  void _toggle(Set<T> values) {
    setState(() {
      if (values.every(_selected.contains)) {
        _selected.removeAll(values);
      } else {
        _selected.addAll(values);
      }
    });
  }

  void _toggleGroup(String name) {
    var key = (_groupingIndex, name);
    setState(() {
      if (!_expandedGroups.remove(key)) _expandedGroups.add(key);
    });
  }

  Widget _choiceRow({
    required String title,
    required String size,
    required bool? checked,
    required VoidCallback? onToggle,
    String? description,
    Widget? action,
    VoidCallback? onTitleTap,
    bool group = false,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Checkbox(
          checked: checked,
          semanticLabel: title,
          onChanged: onToggle == null ? null : (_) => onToggle(),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTitleTap ?? onToggle,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: group
                      ? BTTypography.bodyStrong(context)
                      : BTTypography.body(context),
                ),
                if (description != null)
                  Text(description, style: BTTypography.caption(context)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(size, style: BTTypography.caption(context)),
        if (action != null) ...[const SizedBox(width: 8), action],
      ],
    ),
  );

  Widget _option(
    StorageCleanupOption<T> option, {
    StorageCleanupGrouping<T>? grouping,
  }) => _choiceRow(
    title: grouping?.itemTitle(option.value) ?? option.title,
    size: _sizeLabel(option.bytes),
    description: option.description,
    checked: _selected.contains(option.value),
    onToggle: option.enabled ? () => _toggle({option.value}) : null,
    action: grouping?.itemAction?.call(option.value),
  );

  List<Widget> _groupedSlivers() {
    var grouping = widget.groupings[_groupingIndex];
    var groups = <String, List<StorageCleanupOption<T>>>{};
    for (var option in widget.options) {
      groups.putIfAbsent(grouping.groupBy(option.value), () => []).add(option);
    }
    var names = groups.keys.toList();
    if (grouping.compareGroups != null) names.sort(grouping.compareGroups);
    return [for (var name in names) _group(name, groups[name]!, grouping)];
  }

  Widget _group(
    String name,
    List<StorageCleanupOption<T>> options,
    StorageCleanupGrouping<T> grouping,
  ) {
    var compareItems = grouping.compareItems;
    if (compareItems != null) {
      options.sort((a, b) => compareItems(a.value, b.value));
    }
    var available = {
      for (var option in options)
        if (option.enabled) option.value,
    };
    var bytes = options.fold(0, (sum, option) => sum + (option.bytes ?? 0));
    var expanded = _expandedGroups.contains((_groupingIndex, name));
    var action = grouping.groupAction?.call(
      name,
      options.map((option) => option.value).toList(),
    );
    var expandLabel = '${expanded ? '折叠' : '展开'}$name';
    var isDark = FluentTheme.of(context).brightness == Brightness.dark;
    var header = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isDark
            ? BTColors.surfaceSecondary(context)
            : BTColors.surfacePrimary(context),
        border: expanded
            ? Border(bottom: BorderSide(color: BTColors.divider(context)))
            : null,
      ),
      child: _choiceRow(
        title: '$name · ${options.length} 项',
        size: BTFileTool.formatSize(bytes),
        checked: _checked(available),
        onToggle: available.isEmpty ? null : () => _toggle(available),
        onTitleTap: () => _toggleGroup(name),
        group: true,
        action: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ?action,
            Tooltip(
              message: expandLabel,
              child: Semantics(
                label: expandLabel,
                button: true,
                expanded: expanded,
                child: IconButton(
                  onPressed: () => _toggleGroup(name),
                  style: const ButtonStyle(
                    padding: WidgetStatePropertyAll(EdgeInsets.all(8)),
                  ),
                  icon: Icon(
                    expanded
                        ? FluentIcons.chevron_up
                        : FluentIcons.chevron_down,
                    size: 18,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    return SliverPadding(
      key: ValueKey((_groupingIndex, name)),
      padding: const EdgeInsets.only(bottom: 8),
      sliver: DecoratedSliver(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          border: Border.all(color: BTColors.divider(context)),
          borderRadius: BTRadius.smallBR,
        ),
        sliver: SliverMainAxisGroup(
          slivers: [
            if (grouping.pinHeaders)
              PinnedHeaderSliver(child: header)
            else
              SliverToBoxAdapter(child: header),
            if (expanded)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(22, 0, 10, 4),
                sliver: SliverList.builder(
                  itemCount: options.length,
                  itemBuilder: (context, index) =>
                      _option(options[index], grouping: grouping),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    var bytes = widget.options
        .where((o) => _selected.contains(o.value))
        .fold(0, (sum, option) => sum + (option.bytes ?? 0));
    return ContentDialog(
      title: Text(widget.title),
      constraints: const BoxConstraints(maxWidth: 520),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.description),
          const SizedBox(height: 16),
          if (widget.groupings.isNotEmpty) ...[
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: BTSegmentedControl(
                selectedIndex: _groupingIndex,
                options: widget.groupings.map((group) => group.label).toList(),
                compact: true,
                onChanged: (index) => setState(() => _groupingIndex = index),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Checkbox(
            checked: _checked(_available),
            content: const Text('全选'),
            onChanged: _available.isEmpty ? null : (_) => _toggle(_available),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.4,
            ),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _listBackground,
                border: Border.all(color: BTColors.divider(context)),
                borderRadius: BTRadius.mediumBR,
              ),
              child: CustomScrollView(
                key: ValueKey(_groupingIndex),
                shrinkWrap: true,
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(4, 4, 16, 4),
                    sliver: widget.groupings.isEmpty
                        ? SliverList.list(
                            children: widget.options.map(_option).toList(),
                          )
                        : SliverMainAxisGroup(slivers: _groupedSlivers()),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '已选 ${_selected.length} 项 · '
            '${BTFileTool.formatSize(bytes)}',
          ),
        ],
      ),
      actions: [
        Button(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _selected.isEmpty
              ? null
              : () => Navigator.of(context).pop(Set<T>.of(_selected)),
          child: const Text('清理所选'),
        ),
      ],
    );
  }
}
