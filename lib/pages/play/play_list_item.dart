// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../models/hive/play_model.dart';
import '../../store/play_store.dart';

/// 播放列表项
class PlayListItem extends ConsumerStatefulWidget {
  /// 播放项
  final PlayHiveModel item;

  /// 构造
  const PlayListItem({super.key, required this.item});

  @override
  ConsumerState<PlayListItem> createState() => _PlayListItemState();
}

/// 播放列表项状态
class _PlayListItemState extends ConsumerState<PlayListItem> {
  /// 播放 Hive
  final PlayHive hive = PlayHive();

  /// item
  PlayHiveModel get item => widget.item;

  @override
  Widget build(BuildContext context) {
    return Card(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Subject: ${item.subjectId}'),
          Text('Items: ${item.items.length}'),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            Button(
                child: const Text('Play'),
                onPressed: () {
                  hive.open(subject: item.subjectId);
                  // context.go('/play/${item.subjectId}');
                }),
          ])
        ],
      ),
    );
  }
}
