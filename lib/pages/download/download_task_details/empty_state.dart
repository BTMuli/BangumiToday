part of '../download_task_details.dart';

class _DetailEmptyState extends StatelessWidget {
  const _DetailEmptyState({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    var accent = FluentTheme.of(context).accentColor;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.09),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 27, color: accent),
          ),
          SizedBox(height: 14),
          Text(title, style: BTTypography.subtitle(context)),
          SizedBox(height: 5),
          Text(description, style: BTTypography.caption(context)),
        ],
      ),
    );
  }
}

class _DetailTabError extends StatelessWidget {
  const _DetailTabError({required this.error, required this.onRetry});

  final String error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: BTColors.errorLight(context).withValues(alpha: 0.09),
              shape: BoxShape.circle,
            ),
            child: Icon(
              FluentIcons.error,
              size: 27,
              color: BTColors.errorLight(context),
            ),
          ),
          SizedBox(height: 14),
          Text('无法加载列表', style: BTTypography.subtitle(context)),
          SizedBox(height: 5),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              error,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: BTTypography.caption(context),
            ),
          ),
          if (onRetry != null) ...[
            SizedBox(height: 12),
            Button(onPressed: onRetry, child: const Text('重试')),
          ],
        ],
      ),
    );
  }
}
