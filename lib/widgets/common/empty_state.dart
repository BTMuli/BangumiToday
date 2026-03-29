import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

enum EmptyStateType {
  noData,
  noSearchResult,
  noCollection,
  networkError,
  loading,
  error,
}

class BTEmptyState extends StatelessWidget {
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

  IconData _getIcon() {
    switch (type) {
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
    switch (type) {
      case EmptyStateType.noData:
      case EmptyStateType.noSearchResult:
      case EmptyStateType.noCollection:
        return FluentTheme.of(context).accentColor.lighter;
      case EmptyStateType.networkError:
      case EmptyStateType.error:
        return Colors.red;
      case EmptyStateType.loading:
        return FluentTheme.of(context).accentColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (type == EmptyStateType.loading) ...[
              ProgressRing(),
              SizedBox(height: 16.h),
            ] else ...[
              icon ??
                  Icon(_getIcon(), size: 64.sp, color: _getIconColor(context)),
              SizedBox(height: 16.h),
            ],
            if (title != null) ...[
              Text(
                title!,
                style: FluentTheme.of(context).typography.subtitle,
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8.h),
            ],
            if (message != null) ...[
              Text(
                message!,
                style: FluentTheme.of(
                  context,
                ).typography.body?.copyWith(color: Colors.grey[100]),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 24.h),
            ],
            if (customContent != null) ...[
              customContent!,
              SizedBox(height: 24.h),
            ],
            if (onAction != null && actionText != null) ...[
              FilledButton(onPressed: onAction, child: Text(actionText!)),
            ],
          ],
        ),
      ),
    );
  }
}
