part of '../subject_detail_page.dart';

extension _SubjectDetailContextMenu on _SubjectDetailPageState {
  Widget buildContextMenu(BuildContext context, EditableTextState state) {
    var isDark = FluentTheme.of(context).brightness == Brightness.dark;
    var backgroundColor = isDark ? const Color(0xFF2D2D2D) : Colors.white;
    var textColor = isDark ? Colors.white : Colors.black;
    var hoverColor = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : Colors.black.withValues(alpha: 0.05);

    String getButtonLabel(ContextMenuButtonItem item) {
      if (item.label != null) return item.label!;
      switch (item.type) {
        case ContextMenuButtonType.copy:
          return '复制';
        case ContextMenuButtonType.cut:
          return '剪切';
        case ContextMenuButtonType.paste:
          return '粘贴';
        case ContextMenuButtonType.selectAll:
          return '全选';
        case ContextMenuButtonType.delete:
          return '删除';
        case ContextMenuButtonType.lookUp:
          return '查询';
        case ContextMenuButtonType.searchWeb:
          return '搜索';
        case ContextMenuButtonType.share:
          return '分享';
        case ContextMenuButtonType.liveTextInput:
          return '实时文本输入';
        default:
          return 'Unknown';
      }
    }

    return CustomSingleChildLayout(
      delegate: TextSelectionToolbarLayoutDelegate(
        anchorAbove: state.contextMenuAnchors.primaryAnchor,
        anchorBelow:
            state.contextMenuAnchors.secondaryAnchor ??
            state.contextMenuAnchors.primaryAnchor,
      ),
      child: IntrinsicWidth(
        child: Container(
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(6),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: state.contextMenuButtonItems.map((item) {
                return _ContextMenuButton(
                  label: getButtonLabel(item),
                  textColor: textColor,
                  hoverColor: hoverColor,
                  onPressed: item.onPressed,
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}

class _ContextMenuButton extends StatefulWidget {
  final String label;
  final Color textColor;
  final Color hoverColor;
  final VoidCallback? onPressed;

  const _ContextMenuButton({
    required this.label,
    required this.textColor,
    required this.hoverColor,
    this.onPressed,
  });

  @override
  State<_ContextMenuButton> createState() => _ContextMenuButtonState();
}

class _ContextMenuButtonState extends State<_ContextMenuButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        behavior: HitTestBehavior.opaque,
        child: Container(
          color: _isHovered ? widget.hoverColor : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            widget.label,
            style: TextStyle(color: widget.textColor, fontSize: 14),
          ),
        ),
      ),
    );
  }
}
