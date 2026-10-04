// Package imports:
import 'package:fluent_ui/fluent_ui.dart';

/// 选项面板与选框分开定位，优先向下展开，空间不足时向上展开。
class BtSelect<T> extends StatefulWidget {
  final T? value;
  final List<ComboBoxItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final bool isExpanded;

  const BtSelect({
    super.key,
    required this.items,
    this.value,
    this.onChanged,
    this.isExpanded = false,
  });

  @override
  State<BtSelect<T>> createState() => _BtSelectState<T>();
}

class _BtSelectState<T> extends State<BtSelect<T>> {
  final FlyoutController _controller = FlyoutController();
  final GlobalKey _targetKey = GlobalKey();
  bool _open = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _showOptions() async {
    if (_open || widget.onChanged == null) return;
    var box = _targetKey.currentContext!.findRenderObject()! as RenderBox;
    var width = box.size.width;
    setState(() => _open = true);
    try {
      var result = await _controller.showFlyout<T>(
        autoModeConfiguration: FlyoutAutoConfiguration(
          preferredMode: FlyoutPlacementMode.bottomLeft,
        ),
        additionalOffset: 6,
        forceAvailableSpace: true,
        builder: (flyoutContext) => MenuFlyout(
          constraints: BoxConstraints(minWidth: width, maxWidth: width),
          items: [
            for (var item in widget.items)
              MenuFlyoutItem(
                text: item.child,
                selected: item.value == widget.value,
                trailing: item.value == widget.value
                    ? const Icon(FluentIcons.check_mark, size: 12)
                    : null,
                closeAfterClick: false,
                onPressed: () => Navigator.of(flyoutContext).pop(item.value),
              ),
          ],
        ),
      );
      if (mounted && result != null) widget.onChanged?.call(result);
    } finally {
      if (mounted) setState(() => _open = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    var selected = widget.items
        .where((item) => item.value == widget.value)
        .firstOrNull;
    var label = selected?.child ?? const Text('请选择');
    return FlyoutTarget(
      key: _targetKey,
      controller: _controller,
      child: Semantics(
        expanded: _open,
        child: Button(
          onPressed: widget.items.isEmpty || widget.onChanged == null
              ? null
              : _showOptions,
          child: Row(
            mainAxisSize: widget.isExpanded
                ? MainAxisSize.max
                : MainAxisSize.min,
            children: [
              if (widget.isExpanded) Expanded(child: label) else label,
              const SizedBox(width: 12),
              const Icon(FluentIcons.chevron_down, size: 8),
            ],
          ),
        ),
      ),
    );
  }
}
