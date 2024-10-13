// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

// Project imports:
import '../../components/play/play_history_item.dart';
import '../../store/play_store.dart';

/// 播放历史记录
class PlayHistoryPage extends StatefulWidget {
  /// 构造
  const PlayHistoryPage({super.key});

  @override
  State<PlayHistoryPage> createState() => _PlayHistoryPageState();
}

/// 状态
class _PlayHistoryPageState extends State<PlayHistoryPage> {
  /// Hive
  final PlayHive hive = PlayHive();

  @override
  Widget build(BuildContext context) {
    if (hive.values.isEmpty) {
      return const ScaffoldPage(
        padding: EdgeInsets.zero,
        content: Center(child: Text('暂无播放历史')),
      );
    }
    return ScaffoldPage(
      padding: EdgeInsets.zero,
      content: ListView.separated(
        padding: const EdgeInsets.all(8),
        itemCount: hive.values.length,
        itemBuilder: (context, index) => PlayHistoryItemWidget(
          hive.values[index],
          hive,
        ),
        separatorBuilder: (context, index) => SizedBox(height: 8.h),
      ),
    );
  }
}
