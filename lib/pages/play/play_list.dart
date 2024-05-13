// Package imports:
import 'package:fluent_ui/fluent_ui.dart';

// Project imports:
import '../../store/play_store.dart';
import 'play_list_item.dart';

/// 播放列表页面，显示播放列表，按照条目进行划分
class PlayListPage extends StatefulWidget {
  /// 构造
  const PlayListPage({super.key});

  @override
  State<PlayListPage> createState() => _PlayListPageState();
}

/// 状态
class _PlayListPageState extends State<PlayListPage> {
  /// hive
  final PlayHive hive = PlayHive();

  @override
  void initState() {
    super.initState();
    hive.addListener(listenHive);
  }

  /// 监听hive
  void listenHive() {
    if (mounted) setState(() {});
  }

  /// 构建头部
  Widget buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: const Text('播放进度记录'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldPage(
      header: buildHeader(),
      content: ListView.separated(
        itemCount: hive.values.length,
        itemBuilder: (context, index) {
          var item = hive.values[index];
          return PlayListItem(item: item);
        },
        separatorBuilder: (context, index) => const SizedBox(height: 8),
      ),
    );
  }
}
