part of '../rss_bmf_workspace.dart';

class _BmfPeriodFilter extends StatefulWidget {
  const _BmfPeriodFilter({
    required this.title,
    required this.currentValue,
    required this.currentLabel,
    required this.options,
    required this.selectedValues,
    required this.columns,
    required this.maxWidth,
    required this.maxHeight,
    required this.onChanged,
  });

  final String title;
  final int currentValue;
  final String currentLabel;
  final Map<int, String> options;
  final Set<int>? selectedValues;
  final int columns;
  final double maxWidth;
  final double maxHeight;
  final ValueChanged<Set<int>?>? onChanged;

  @override
  State<_BmfPeriodFilter> createState() => _BmfPeriodFilterState();
}

class _BmfPeriodFilterState extends State<_BmfPeriodFilter> {
  static const _gap = 6.0;
  static const _margin = 8.0;

  final FlyoutController _controller = FlyoutController();
  final GlobalKey _targetKey = GlobalKey();
  final ScrollController _scrollController = ScrollController(
    keepScrollOffset: false,
  );
  bool _open = false;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String get _label {
    var selected = widget.selectedValues;
    if (selected == null) return '全部${widget.title}';
    if (selected.isEmpty) return '未选${widget.title}';
    if (selected.length > 2) return '${selected.length} 个${widget.title}';
    return widget.options.entries
        .where((option) => selected.contains(option.key))
        .map((option) => option.value)
        .join('、');
  }

  Future<void> _showOptions() async {
    if (_open || widget.onChanged == null) return;
    var target = _targetKey.currentContext!.findRenderObject()! as RenderBox;
    var root = Navigator.of(context).context.findRenderObject()! as RenderBox;
    var targetTop = target.localToGlobal(Offset.zero, ancestor: root).dy;
    var below =
        root.size.height - targetTop - target.size.height - _gap - _margin;
    var above = targetTop - _gap - _margin;
    var rows = (widget.options.length / widget.columns).ceil();
    var itemHeight = 32.0 * MediaQuery.textScalerOf(context).scale(14) / 14;
    var desiredHeight = (56 + rows * itemHeight + (rows - 1) * 6).clamp(
      0.0,
      widget.maxHeight,
    );
    var showBelow = below >= desiredHeight || below >= above;
    var maxHeight = (showBelow ? below : above).clamp(0.0, widget.maxHeight);
    var selected = widget.selectedValues == null
        ? null
        : Set<int>.of(widget.selectedValues!);
    setState(() => _open = true);
    try {
      var result = await _controller.showFlyout<({Set<int>? values})>(
        placementMode: showBelow
            ? FlyoutPlacementMode.bottomLeft
            : FlyoutPlacementMode.topLeft,
        additionalOffset: _gap,
        margin: _margin,
        forceAvailableSpace: true,
        builder: (flyoutContext) => StatefulBuilder(
          builder: (context, updateFlyout) {
            void change(Set<int>? values) {
              updateFlyout(() => selected = values);
            }

            var options = widget.options.entries.toList();
            var allSelected = selected == null;
            var theme = FluentTheme.of(context);
            var accent = theme.accentColor.defaultBrushFor(theme.brightness);
            var itemStyle = ButtonStyle(
              padding: const WidgetStatePropertyAll(
                EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              ),
              shape: WidgetStatePropertyAll(
                RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                  side: BorderSide(color: BTColors.divider(context)),
                ),
              ),
            );
            var checkedStyle = itemStyle.copyWith(
              backgroundColor: WidgetStateProperty.resolveWith(
                (states) => FilledButton.backgroundColor(theme, states),
              ),
              foregroundColor: WidgetStateProperty.resolveWith(
                (states) => FilledButton.foregroundColor(theme, states),
              ),
              shape: WidgetStatePropertyAll(
                RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                  side: BorderSide(color: accent, width: 1.5),
                ),
              ),
            );
            var toggleStyle = ToggleButtonThemeData(
              checkedButtonStyle: checkedStyle,
              uncheckedButtonStyle: itemStyle,
            );
            return FlyoutContent(
              padding: const EdgeInsets.all(8),
              constraints: BoxConstraints(
                maxWidth: widget.maxWidth,
                maxHeight: maxHeight,
              ),
              child: SizedBox(
                width: widget.maxWidth,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Text(
                          widget.title,
                          style: BTTypography.bodyStrong(context),
                        ),
                        const Spacer(),
                        Tooltip(
                          message: allSelected ? '取消全选' : '全选${widget.title}',
                          child: ToggleButton(
                            checked: allSelected,
                            style: toggleStyle,
                            onChanged: (checked) => change(checked ? null : {}),
                            child: const Text('全选'),
                          ),
                        ),
                        const SizedBox(width: 6),
                        FilledButton(
                          onPressed: () => Navigator.of(flyoutContext).pop((
                            values: selected == null
                                ? null
                                : Set<int>.of(selected!),
                          )),
                          child: const Text('确认'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Flexible(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          var columns = ((constraints.maxWidth + 6) / 80)
                              .floor()
                              .clamp(1, widget.columns);
                          return Scrollbar(
                            controller: _scrollController,
                            child: GridView.builder(
                              controller: _scrollController,
                              primary: false,
                              shrinkWrap: true,
                              padding: EdgeInsets.zero,
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: columns,
                                    mainAxisExtent: itemHeight,
                                    crossAxisSpacing: 6,
                                    mainAxisSpacing: 6,
                                  ),
                              itemCount: options.length,
                              itemBuilder: (context, index) {
                                var option = options[index];
                                var checked =
                                    selected?.contains(option.key) ?? true;
                                var current = option.key == widget.currentValue;
                                var badgeColor = checked
                                    ? FilledButton.foregroundColor(
                                        theme,
                                        const {},
                                      )
                                    : accent;
                                return ToggleButton(
                                  key: ValueKey(option.key),
                                  checked: checked,
                                  style: toggleStyle,
                                  onChanged: (checked) {
                                    var values = <int>{
                                      ...(selected ?? widget.options.keys),
                                    };
                                    if (checked) {
                                      values.add(option.key);
                                    } else {
                                      values.remove(option.key);
                                    }
                                    change(
                                      values.containsAll(widget.options.keys)
                                          ? null
                                          : values,
                                    );
                                  },
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          option.value,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (current) ...[
                                        const SizedBox(width: 4),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 3,
                                            vertical: 1,
                                          ),
                                          decoration: BoxDecoration(
                                            color: badgeColor.withValues(
                                              alpha: 0.16,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              3,
                                            ),
                                          ),
                                          child: Text(
                                            widget.currentLabel,
                                            style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.w600,
                                              color: badgeColor,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
      if (mounted && result != null) widget.onChanged?.call(result.values);
    } finally {
      if (mounted) setState(() => _open = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FlyoutTarget(
      key: _targetKey,
      controller: _controller,
      child: Semantics(
        label: '${widget.title}筛选',
        expanded: _open,
        child: Button(
          onPressed: widget.options.isEmpty || widget.onChanged == null
              ? null
              : _showOptions,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_label),
              const SizedBox(width: 8),
              const BtIcon(FluentIcons.chevron_down, size: 8),
            ],
          ),
        ),
      ),
    );
  }
}
