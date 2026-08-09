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
