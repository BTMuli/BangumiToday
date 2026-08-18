part of '../subject_search_page.dart';

class _AnimatedSearchButton extends StatefulWidget {
  final VoidCallback onPressed;
  final bool isLoading;

  const _AnimatedSearchButton({
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  State<_AnimatedSearchButton> createState() => _AnimatedSearchButtonState();
}

class _AnimatedSearchButtonState extends State<_AnimatedSearchButton>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: BTTheme.animationDurationFast,
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    _controller.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    _controller.reverse();
  }

  void _handleTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    var accentColor = FluentTheme.of(context).accentColor;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        onTap: widget.isLoading ? null : widget.onPressed,
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) {
            return Transform.scale(scale: _scaleAnimation.value, child: child);
          },
          child: AnimatedContainer(
            duration: BTTheme.animationDurationFast,
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _isHovered
                  ? accentColor
                  : accentColor.withValues(alpha: 0.9),
              borderRadius: BTRadius.mediumBR,
              boxShadow: _isHovered
                  ? [
                      BoxShadow(
                        color: accentColor.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: widget.isLoading
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: const ProgressRing(
                      strokeWidth: 2,
                      activeColor: Colors.white,
                    ),
                  )
                : Icon(FluentIcons.search, size: 14, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class _AnimatedSearchBox extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onClear;

  const _AnimatedSearchBox({
    required this.controller,
    this.onSubmitted,
    this.onClear,
  });

  @override
  State<_AnimatedSearchBox> createState() => _AnimatedSearchBoxState();
}

class _AnimatedSearchBoxState extends State<_AnimatedSearchBox> {
  final FocusNode _focusNode = FocusNode();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChange);
    _hasText = widget.controller.text.isNotEmpty;
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChange() {
    var hasText = widget.controller.text.isNotEmpty;
    if (hasText != _hasText) {
      setState(() => _hasText = hasText);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextBox(
            controller: widget.controller,
            focusNode: _focusNode,
            placeholder: '搜索条目名称...',
            placeholderStyle: TextStyle(
              color: BTColors.textTertiary(context),
              fontSize: 14,
            ),
            style: BTTypography.body(context),
            onSubmitted: widget.onSubmitted,
          ),
        ),
        if (_hasText) ...[
          SizedBox(width: 8),
          GestureDetector(
            onTap: widget.onClear,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: AnimatedOpacity(
                duration: BTTheme.animationDurationFast,
                opacity: _hasText ? 1.0 : 0.0,
                child: Container(
                  padding: EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: BTColors.textSecondary(
                      context,
                    ).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    FluentIcons.clear,
                    size: 12,
                    color: BTColors.textSecondary(context),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(width: 8),
        ] else
          SizedBox(width: 12),
      ],
    );
  }
}

class _FilterChip extends StatefulWidget {
  final String label;
  final bool isSelected;
  final VoidCallback? onDeleted;
  final VoidCallback? onTap;

  const _FilterChip({
    required this.label,
    this.isSelected = false,
    this.onDeleted,
    this.onTap,
  });

  @override
  State<_FilterChip> createState() => _FilterChipState();
}

class _FilterChipState extends State<_FilterChip>
    with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: BTTheme.animationDurationFast,
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var accentColor = FluentTheme.of(context).accentColor;
    var isDark = FluentTheme.of(context).brightness == Brightness.dark;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: (_) => _controller.forward(),
        onTapUp: (_) {
          _controller.reverse();
          widget.onTap?.call();
        },
        onTapCancel: () => _controller.reverse(),
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) {
            return Transform.scale(scale: _scaleAnimation.value, child: child);
          },
          child: AnimatedContainer(
            duration: BTTheme.animationDurationFast,
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: widget.isSelected
                  ? accentColor.withValues(alpha: _isHovered ? 1.0 : 0.9)
                  : (isDark
                        ? Colors.white.withValues(
                            alpha: _isHovered ? 0.1 : 0.05,
                          )
                        : Colors.black.withValues(
                            alpha: _isHovered ? 0.08 : 0.03,
                          )),
              borderRadius: BTRadius.roundBR,
              border: Border.all(
                color: widget.isSelected
                    ? accentColor
                    : (isDark
                          ? Colors.white.withValues(alpha: 0.15)
                          : Colors.black.withValues(alpha: 0.1)),
                width: 1,
              ),
              boxShadow: _isHovered
                  ? [
                      BoxShadow(
                        color: accentColor.withValues(alpha: 0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.label,
                  style: TextStyle(
                    color: widget.isSelected
                        ? Colors.white
                        : BTColors.textPrimary(context),
                    fontSize: 12,
                    fontWeight: widget.isSelected
                        ? FontWeight.w600
                        : FontWeight.w400,
                  ),
                ),
                if (widget.isSelected && widget.onDeleted != null) ...[
                  SizedBox(width: 4),
                  GestureDetector(
                    onTap: widget.onDeleted,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: Icon(
                        FluentIcons.chrome_close,
                        size: 9,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
