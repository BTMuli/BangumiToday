part of '../download_task_details.dart';

class _DetailTabBar extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: BTColors.surfacePrimary(context),
        border: Border(bottom: BorderSide(color: BTColors.divider(context))),
      ),
      padding: EdgeInsets.fromLTRB(12, 7, 12, 0),
      child: Row(
        children: [
          for (var i = 0; i < tabs.length; i++)
            Expanded(
              child: _DetailTabItem(
                tab: tabs[i],
                selected: i == index,
                onTap: () => onChanged(i),
              ),
            ),
          if (trailing != null)
            Padding(padding: EdgeInsets.only(left: 8), child: trailing),
        ],
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
  });

  final _DetailTab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_DetailTabItem> createState() => _DetailTabItemState();
}

class _DetailTabItemState extends State<_DetailTabItem> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    var accent = FluentTheme.of(context).accentColor;
    var foreground = widget.selected ? accent : BTColors.textSecondary(context);
    return MouseRegion(
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
                : _hovered
                ? accent.withValues(alpha: 0.07)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
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
    );
  }
}
