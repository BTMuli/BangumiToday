// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:intl/intl.dart';

// Project imports:
import '../../core/theme/bt_theme.dart';

class RssRefreshStatus extends StatelessWidget {
  const RssRefreshStatus({super.key, required this.lastUpdated});

  final DateTime? lastUpdated;

  @override
  Widget build(BuildContext context) {
    var updated = lastUpdated;
    return Text(
      updated == null
          ? '尚未成功刷新'
          : '上次刷新 ${DateFormat('MM-dd HH:mm').format(updated.toLocal())}',
      style: BTTypography.caption(context),
    );
  }
}
