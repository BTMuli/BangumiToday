import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../core/theme/bt_theme.dart';

enum EmptyStateType {
  noData,
  noSearchResult,
  noCollection,
  networkError,
  loading,
  error,
}

class BTEmptyState extends StatefulWidget {
  final EmptyStateType type;
  final String? title;
  final String? message;
  final Widget? icon;
  final String? actionText;
  final VoidCallback? onAction;
  final Widget? customContent;

  const BTEmptyState({
    super.key,
    required this.type,
    this.title,
    this.message,
    this.icon,
    this.actionText,
    this.onAction,
    this.customContent,
  });

  factory BTEmptyState.noData({
    String? title,
    String? message,
    String? actionText,
    VoidCallback? onAction,
  }) {
    return BTEmptyState(
      type: EmptyStateType.noData,
      title: title ?? '暂无数据',
      message: message ?? '这里还没有任何内容',
      actionText: actionText,
      onAction: onAction,
    );
  }

  factory BTEmptyState.noSearchResult({
    String? keyword,
    String? actionText,
    VoidCallback? onAction,
  }) {
    return BTEmptyState(
      type: EmptyStateType.noSearchResult,
      title: '未找到相关内容',
      message: keyword != null ? '未找到与"$keyword"相关的内容' : '请尝试其他搜索条件',
      actionText: actionText ?? '清除筛选',
      onAction: onAction,
    );
  }

  factory BTEmptyState.noCollection({
    String? actionText,
    VoidCallback? onAction,
  }) {
    return BTEmptyState(
      type: EmptyStateType.noCollection,
      title: '收藏夹为空',
      message: '您还没有收藏任何内容，去发现更多精彩吧',
      actionText: actionText ?? '浏览今日放送',
      onAction: onAction,
    );
  }

  factory BTEmptyState.networkError({
    String? actionText,
    VoidCallback? onAction,
  }) {
    return BTEmptyState(
      type: EmptyStateType.networkError,
      title: '网络连接失败',
      message: '请检查您的网络连接后重试',
      actionText: actionText ?? '重试',
      onAction: onAction,
    );
  }

  factory BTEmptyState.loading({String? message}) {
    return BTEmptyState(
      type: EmptyStateType.loading,
      message: message ?? '加载中...',
    );
  }

  factory BTEmptyState.error({
    String? title,
    String? message,
    String? actionText,
    VoidCallback? onAction,
  }) {
    return BTEmptyState(
      type: EmptyStateType.error,
      title: title ?? '加载失败',
      message: message ?? '内容加载失败，请重试',
      actionText: actionText ?? '重试',
      onAction: onAction,
    );
  }

  @override
  State<BTEmptyState> createState() => _BTEmptyStateState();
}

class _BTEmptyStateState extends State<BTEmptyState>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOutBack),
      ),
    );

    _slideAnimation = Tween<double>(begin: 20.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.2, 0.7, curve: Curves.easeOutCubic),
      ),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  IconData _getIcon() {
    switch (widget.type) {
      case EmptyStateType.noData:
        return FluentIcons.folder;
      case EmptyStateType.noSearchResult:
        return FluentIcons.search;
      case EmptyStateType.noCollection:
        return FluentIcons.heart_broken;
      case EmptyStateType.networkError:
        return FluentIcons.plug_disconnected;
      case EmptyStateType.loading:
        return FluentIcons.sync;
      case EmptyStateType.error:
        return FluentIcons.error_badge;
    }
  }

  Color _getIconColor(BuildContext context) {
    switch (widget.type) {
      case EmptyStateType.noData:
      case EmptyStateType.noSearchResult:
      case EmptyStateType.noCollection:
        return FluentTheme.of(context).accentColor.lighter;
      case EmptyStateType.networkError:
      case EmptyStateType.error:
        return BTColors.errorLight(context);
      case EmptyStateType.loading:
        return FluentTheme.of(context).accentColor;
    }
  }

  Widget _buildAnimatedIcon(BuildContext context) {
    if (widget.type == EmptyStateType.loading) {
      return SizedBox(
        width: 64.w,
        height: 64.w,
        child: ProgressRing(
          strokeWidth: 3,
          activeColor: _getIconColor(context),
        ),
      );
    }

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 800),
      curve: Curves.elasticOut,
      builder: (context, value, child) {
        return Transform.scale(
          scale: 0.5 + (value * 0.5),
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: Container(
        width: 80.w,
        height: 80.w,
        decoration: BoxDecoration(
          color: _getIconColor(context).withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: widget.icon ??
              Icon(
                _getIcon(),
                size: 40.sp,
                color: _getIconColor(context),
              ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Opacity(
            opacity: _fadeAnimation.value,
            child: Transform.scale(
              scale: _scaleAnimation.value,
              child: Transform.translate(
                offset: Offset(0, _slideAnimation.value),
                child: child,
              ),
            ),
          );
        },
        child: Padding(
          padding: EdgeInsets.all(32.w),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildAnimatedIcon(context),
              SizedBox(height: 24.h),
              if (widget.title != null) ...[
                Text(
                  widget.title!,
                  style: BTTypography.subtitle(context).copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 8.h),
              ],
              if (widget.message != null) ...[
                Text(
                  widget.message!,
                  style: BTTypography.body(context).copyWith(
                    color: BTColors.textSecondary(context),
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 24.h),
              ],
              if (widget.customContent != null) ...[
                widget.customContent!,
                SizedBox(height: 24.h),
              ],
              if (widget.onAction != null && widget.actionText != null)
                _AnimatedActionButton(
                  text: widget.actionText!,
                  onPressed: widget.onAction!,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnimatedActionButton extends StatefulWidget {
  final String text;
  final VoidCallback onPressed;

  const _AnimatedActionButton({
    required this.text,
    required this.onPressed,
  });

  @override
  State<_AnimatedActionButton> createState() => _AnimatedActionButtonState();
}

class _AnimatedActionButtonState extends State<_AnimatedActionButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: BTTheme.animationDurationFast,
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    _controller.forward();
  }

  void _onTapUp(TapUpDetails details) {
    _controller.reverse();
  }

  void _onTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        onTap: widget.onPressed,
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: child,
            );
          },
          child: AnimatedContainer(
            duration: BTTheme.animationDurationFast,
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
            decoration: BoxDecoration(
              color: _isHovered
                  ? FluentTheme.of(context).accentColor
                  : FluentTheme.of(context).accentColor.withValues(alpha: 0.9),
              borderRadius: BTRadius.mediumBR,
              boxShadow: _isHovered
                  ? [
                      BoxShadow(
                        color: FluentTheme.of(context)
                            .accentColor
                            .withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Text(
              widget.text,
              style: TextStyle(
                color: Colors.white,
                fontSize: 14.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class BTEmptyStateWithRetry extends StatelessWidget {
  final EmptyStateType type;
  final String? title;
  final String? message;
  final VoidCallback onRetry;
  final String? retryText;

  const BTEmptyStateWithRetry({
    super.key,
    required this.type,
    required this.onRetry,
    this.title,
    this.message,
    this.retryText,
  });

  @override
  Widget build(BuildContext context) {
    return BTEmptyState(
      type: type,
      title: title,
      message: message,
      actionText: retryText ?? '重试',
      onAction: onRetry,
    );
  }
}

class BTLoadingState extends StatelessWidget {
  final String? message;
  final double? progress;

  const BTLoadingState({
    super.key,
    this.message,
    this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 48.w,
            height: 48.w,
            child: ProgressRing(
              value: progress,
              strokeWidth: 3,
              activeColor: FluentTheme.of(context).accentColor,
            ),
          ),
          if (message != null) ...[
            SizedBox(height: 16.h),
            Text(
              message!,
              style: BTTypography.body(context).copyWith(
                color: BTColors.textSecondary(context),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
