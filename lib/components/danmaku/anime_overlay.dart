// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:jiffy/jiffy.dart';

// Project imports:
import '../../models/source/request_danmaku.dart';

/// AnimeSource列表，用于选择弹幕源
Future<DanmakuSearchAnimeDetails?> selectAnime(
  BuildContext context,
  List<DanmakuSearchAnimeDetails> animes,
) async {
  DanmakuSearchAnimeDetails? selected;
  await showDialog(
    barrierDismissible: true,
    context: context,
    builder: (context) {
      return ContentDialog(
        title: const Text('选择动画'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: animes.map((anime) {
            return ListTile(
              title: Text(
                '${anime.animeId} ${Jiffy.parse(anime.startDate).yMd}',
              ),
              subtitle: Text(anime.animeTitle ?? ''),
              onPressed: () {
                selected = anime;
                Navigator.of(context).pop();
              },
            );
          }).toList(),
        ),
        actions: [
          Button(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('取消'),
          ),
        ],
      );
    },
  );
  return selected;
}
