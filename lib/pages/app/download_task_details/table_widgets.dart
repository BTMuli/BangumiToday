part of '../download_task_details.dart';

/// 让分区内容可通过键盘滚动的包装：
/// 自身可被 Tab 聚焦，方向键/翻页键/Home/End 直接驱动 [ScrollController]。
class _KeyboardScrollable extends StatefulWidget {
  const _KeyboardScrollable({required this.builder});

  final Widget Function(BuildContext context, ScrollController controller)
  builder;

  @override
  State<_KeyboardScrollable> createState() => _KeyboardScrollableState();
}

class _KeyboardScrollableState extends State<_KeyboardScrollable> {
  static const _lineExtent = 56.0;

  final ScrollController _controller = ScrollController();
  final FocusNode _focusNode = FocusNode(debugLabel: 'download-detail-scroll');

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent || !_controller.hasClients) {
      return KeyEventResult.ignored;
    }
    var position = _controller.position;
    double? target;
    var key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowUp) {
      target = position.pixels - _lineExtent;
    } else if (key == LogicalKeyboardKey.arrowDown) {
      target = position.pixels + _lineExtent;
    } else if (key == LogicalKeyboardKey.pageUp) {
      target = position.pixels - position.viewportDimension * 0.8;
    } else if (key == LogicalKeyboardKey.pageDown) {
      target = position.pixels + position.viewportDimension * 0.8;
    } else if (key == LogicalKeyboardKey.home) {
      target = position.minScrollExtent;
    } else if (key == LogicalKeyboardKey.end) {
      target = position.maxScrollExtent;
    }
    if (target == null) return KeyEventResult.ignored;
    unawaited(
      position.moveTo(
        target
            .clamp(position.minScrollExtent, position.maxScrollExtent)
            .toDouble(),
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeInOut,
      ),
    );
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      onKeyEvent: _onKey,
      child: widget.builder(context, _controller),
    );
  }
}

class _TableShell extends StatefulWidget {
  const _TableShell({
    required this.header,
    required this.itemCount,
    required this.itemBuilder,
    this.footer,
  });

  final Widget header;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final String? footer;

  @override
  State<_TableShell> createState() => _TableShellState();
}

class _TableShellState extends State<_TableShell> {
  final ScrollController _controller = ScrollController();
  final List<FocusNode> _rowNodes = [];

  @override
  void initState() {
    super.initState();
    _syncRowNodes();
  }

  @override
  void didUpdateWidget(covariant _TableShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncRowNodes();
  }

  @override
  void dispose() {
    _controller.dispose();
    for (var node in _rowNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _syncRowNodes() {
    while (_rowNodes.length < widget.itemCount) {
      _rowNodes.add(
        FocusNode(debugLabel: 'download-table-row-${_rowNodes.length}'),
      );
    }
    if (_rowNodes.length > widget.itemCount) {
      for (var i = widget.itemCount; i < _rowNodes.length; i++) {
        _rowNodes[i].dispose();
      }
      _rowNodes.removeRange(widget.itemCount, _rowNodes.length);
    }
  }

  /// 将焦点移动到相邻行；目标行尚未构建（超出缓存区）时先滚动半屏，
  /// 等它进入构建范围后再重试一次聚焦。
  void _moveFocusFrom(int index, int delta, {bool allowScrollRetry = true}) {
    var target = index + delta;
    if (target < 0 || target >= _rowNodes.length) return;
    var node = _rowNodes[target];
    if (node.hasFocus) return;
    node.requestFocus();
    if (node.context != null) {
      unawaited(
        Scrollable.ensureVisible(
          node.context!,
          alignment: 1,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeInOut,
        ),
      );
      return;
    }
    if (!allowScrollRetry || !_controller.hasClients) return;
    var position = _controller.position;
    var jump = (position.viewportDimension / 2).clamp(100.0, 400.0);
    unawaited(
      position.moveTo(
        (position.pixels + jump)
            .clamp(position.minScrollExtent, position.maxScrollExtent)
            .toDouble(),
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeInOut,
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _moveFocusFrom(target, 0, allowScrollRetry: false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(18),
      child: Container(
        decoration: BoxDecoration(
          color: BTColors.surfacePrimary(context),
          borderRadius: BTRadius.largeBR,
          border: Border.all(color: BTColors.divider(context)),
          boxShadow: BTTheme.shadow(context, level: BTShadowLevel.subtle),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            widget.header,
            Expanded(
              child: ListView.builder(
                controller: _controller,
                itemCount: widget.itemCount,
                itemBuilder: (context, index) {
                  var row = widget.itemBuilder(context, index);
                  if (index >= _rowNodes.length) return row;
                  return _ManagedTableRow(
                    row: row,
                    focusNode: _rowNodes[index],
                    onMoveFocus: (delta) => _moveFocusFrom(index, delta),
                  );
                },
              ),
            ),
            if (widget.footer != null)
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                color: BTColors.surfaceSecondary(context),
                child: Text(
                  widget.footer!,
                  textAlign: TextAlign.center,
                  style: BTTypography.caption(context),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 为表格行提供键盘焦点：方向键在行间移动，聚焦时有高亮。
class _ManagedTableRow extends StatefulWidget {
  const _ManagedTableRow({
    required this.row,
    required this.focusNode,
    required this.onMoveFocus,
  });

  final Widget row;
  final FocusNode focusNode;
  final ValueChanged<int> onMoveFocus;

  @override
  State<_ManagedTableRow> createState() => _ManagedTableRowState();
}

class _ManagedTableRowState extends State<_ManagedTableRow> {
  var _focused = false;

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowUp:
        widget.onMoveFocus(-1);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowDown:
        widget.onMoveFocus(1);
        return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: widget.focusNode,
      onFocusChange: (value) => setState(() => _focused = value),
      onKeyEvent: _onKey,
      child: Stack(
        children: [
          widget.row,
          if (_focused)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: FluentTheme.of(
                        context,
                      ).accentColor.withValues(alpha: 0.6),
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader({
    required this.columns,
    required this.flexes,
    this.sortIndex = -1,
    this.ascending = true,
    this.onSort,
    this.filterIndex = -1,
    this.filterActive = false,
    this.onFilter,
    this.filterController,
  });

  final List<String> columns;
  final List<int> flexes;

  /// 当前排序的列索引，-1 表示未排序
  final int sortIndex;

  /// 是否升序
  final bool ascending;

  /// 排序列点击回调
  final ValueChanged<int>? onSort;

  /// 支持筛选的列索引，-1 表示无
  final int filterIndex;

  /// 是否启用了筛选
  final bool filterActive;

  /// 筛选列点击回调
  final ValueChanged<int>? onFilter;

  /// 筛选列 Flyout 锚点控制器
  final FlyoutController? filterController;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      color: BTColors.surfaceSecondary(context),
      child: Row(
        children: List.generate(columns.length, (index) {
          return Expanded(flex: flexes[index], child: _cell(context, index));
        }),
      ),
    );
  }

  Widget _cell(BuildContext context, int index) {
    var isFilterColumn = index == filterIndex && onFilter != null;
    if (isFilterColumn) {
      var cell = _clickable(
        context,
        index,
        active: filterActive,
        activeIcon: FluentIcons.filter,
        onTap: () => onFilter!(index),
      );
      var controller = filterController;
      if (controller != null) {
        return FlyoutTarget(controller: controller, child: cell);
      }
      return cell;
    }
    if (onSort == null) {
      return _plain(context, index);
    }
    return _clickable(
      context,
      index,
      active: index == sortIndex,
      activeIcon: ascending ? FluentIcons.chevron_up : FluentIcons.chevron_down,
      onTap: () => onSort!(index),
    );
  }

  Widget _plain(BuildContext context, int index) {
    return Text(
      columns[index],
      style: BTTypography.caption(
        context,
      ).copyWith(fontWeight: FontWeight.w600),
    );
  }

  Widget _clickable(
    BuildContext context,
    int index, {
    required bool active,
    required IconData activeIcon,
    required VoidCallback onTap,
  }) {
    return _HeaderCellButton(
      label: columns[index],
      active: active,
      activeIcon: activeIcon,
      onTap: onTap,
    );
  }
}

/// 可键盘交互的表头单元格：回车/空格触发，聚焦时有高亮。
class _HeaderCellButton extends StatefulWidget {
  const _HeaderCellButton({
    required this.label,
    required this.active,
    required this.activeIcon,
    required this.onTap,
  });

  final String label;
  final bool active;
  final IconData activeIcon;
  final VoidCallback onTap;

  @override
  State<_HeaderCellButton> createState() => _HeaderCellButtonState();
}

class _HeaderCellButtonState extends State<_HeaderCellButton> {
  late final FocusNode _focusNode;
  var _hovered = false;
  var _focused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(debugLabel: 'download-table-header-${widget.label}');
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    var key = event.logicalKey;
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.space) {
      widget.onTap();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    var accent = FluentTheme.of(context).accentColor;
    return Focus(
      focusNode: _focusNode,
      onFocusChange: (value) => setState(() => _focused = value),
      onKeyEvent: _onKey,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: BTTheme.animationDurationFast,
            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              color: _hovered || _focused
                  ? accent.withValues(alpha: 0.08)
                  : Colors.transparent,
              borderRadius: BTRadius.smallBR,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: BTTypography.caption(
                      context,
                    ).copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                if (widget.active) ...[
                  SizedBox(width: 4),
                  Icon(widget.activeIcon, size: 12, color: accent),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TableRow extends StatefulWidget {
  const _TableRow({required this.columns, required this.flexes});

  final List<Widget> columns;
  final List<int> flexes;

  @override
  State<_TableRow> createState() => _TableRowState();
}

class _TableRowState extends State<_TableRow> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: BTTheme.animationDurationFast,
        padding: EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        decoration: BoxDecoration(
          color: _hovered
              ? FluentTheme.of(context).accentColor.withValues(alpha: 0.045)
              : Colors.transparent,
          border: Border(bottom: BorderSide(color: BTColors.divider(context))),
        ),
        child: DefaultTextStyle(
          style: BTTypography.caption(
            context,
          ).copyWith(color: BTColors.textPrimary(context)),
          child: Row(
            children: List.generate(
              widget.columns.length,
              (index) => Expanded(
                flex: widget.flexes[index],
                child: widget.columns[index],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
