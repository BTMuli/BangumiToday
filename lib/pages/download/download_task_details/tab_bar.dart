part of '../download_task_details.dart';

class _DetailTabBar extends StatefulWidget {
  const _DetailTabBar({
    required this.tabs,
    required this.index,
    required this.onChanged,
    this.trailing,
  });

  final List<_DetailTab> tabs;
  final int index;
  final ValueChanged<int> onChanged;
  final Widget? trailing;

  @override
  State<_DetailTabBar> createState() => _DetailTabBarState();
}

class _DetailTabBarState extends State<_DetailTabBar> {
  late final List<FocusNode> _nodes = List.generate(
    widget.tabs.length,
    (_) => FocusNode(),
  );

  @override
  void dispose() {
    for (var node in _nodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _select(int index) {
    widget.onChanged(index);
    _nodes[index].requestFocus();
  }

  void _moveFrom(int from, int delta) {
    var next = (from + delta + widget.tabs.length) % widget.tabs.length;
    _select(next);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: BTColors.surfacePrimary(context),
        border: Border(bottom: BorderSide(color: BTColors.divider(context))),
      ),
      padding: EdgeInsets.fromLTRB(12, 7, 12, 0),
      child: FocusTraversalGroup(
        child: Row(
          children: [
            for (var i = 0; i < widget.tabs.length; i++)
              Expanded(
                child: _DetailTabItem(
                  tab: widget.tabs[i],
                  selected: i == widget.index,
                  focusNode: _nodes[i],
                  onTap: () => _select(i),
                  onMoveFocus: (delta) => _moveFrom(i, delta),
                  onEscape: () => _select(0),
                ),
              ),
            if (widget.trailing != null)
              Padding(
                padding: EdgeInsets.only(left: 8),
                child: widget.trailing,
              ),
          ],
        ),
      ),
    );
  }
}

class _DetailTab {
  const _DetailTab({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

class _DetailTabItem extends StatefulWidget {
  const _DetailTabItem({
    required this.tab,
    required this.selected,
    required this.onTap,
    required this.focusNode,
    required this.onMoveFocus,
    required this.onEscape,
  });

  final _DetailTab tab;
  final bool selected;
  final VoidCallback onTap;
  final FocusNode focusNode;
  final ValueChanged<int> onMoveFocus;
  final VoidCallback onEscape;

  @override
  State<_DetailTabItem> createState() => _DetailTabItemState();
}

class _DetailTabItemState extends State<_DetailTabItem> {
  var _hovered = false;
  var _focused = false;

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    var key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowRight) {
      widget.onMoveFocus(1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      widget.onMoveFocus(-1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.space) {
      widget.onTap();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      widget.onEscape();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    var accent = FluentTheme.of(context).accentColor;
    var foreground = widget.selected ? accent : BTColors.textSecondary(context);
    return Focus(
      focusNode: widget.focusNode,
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
            margin: EdgeInsets.fromLTRB(2, 0, 2, 7),
            padding: EdgeInsets.symmetric(vertical: 8),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: widget.selected
                  ? accent.withValues(alpha: 0.14)
                  : _hovered || _focused
                  ? accent.withValues(alpha: 0.07)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(9),
              border: _focused
                  ? Border.all(color: accent.withValues(alpha: 0.6))
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(widget.tab.icon, size: 15, color: foreground),
                SizedBox(width: 6),
                Flexible(
                  child: Text(
                    widget.tab.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: widget.selected
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: foreground,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
