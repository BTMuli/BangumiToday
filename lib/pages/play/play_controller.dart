// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:ns_danmaku/ns_danmaku.dart';

// Project imports:
import '../../../models/source/request_danmaku.dart';
import '../../../store/play_store.dart';

/// Provider
final playControllerProvider =
    StateNotifierProvider<PlayController, PlayControllerState>((ref) {
  return PlayController(PlayControllerState());
});

class PlayControllerState {
  /// 是否展示弹幕
  bool showDanmaku = false;

  /// hive，用于存储播放列表&播放进度
  late PlayHive hive = PlayHive();

  /// 匹配到的弹幕动画
  List<DanmakuSearchAnimeDetails> danmakuMatchAnime = [];

  /// Player
  late BtPlayer player = BtPlayer();

  /// PlayerController
  late VideoController video = VideoController(player);

  /// 播放速度
  double playSpeed = 1.0;

  /// 弹幕控制器
  late DanmakuController danmaku;

  /// 弹幕位置
  late int danmakuPosition = -1;

  /// 弹幕列表，以秒单位的计时作为索引
  Map<int, List<DanmakuEpisodeComment>> comments = {};

  /// copyWith
  PlayControllerState copyWith({
    bool? showDanmaku,
    PlayHive? hive,
    List<DanmakuSearchAnimeDetails>? danmakuMatchAnime,
    BtPlayer? player,
    VideoController? video,
    DanmakuController? danmaku,
    double? playSpeed,
    Map<int, List<DanmakuEpisodeComment>>? comments,
  }) {
    return PlayControllerState()
      ..showDanmaku = showDanmaku ?? this.showDanmaku
      ..danmakuMatchAnime = danmakuMatchAnime ?? this.danmakuMatchAnime
      ..player = player ?? this.player
      ..playSpeed = playSpeed ?? this.playSpeed
      ..video = video ?? this.video
      ..danmaku = danmaku ?? this.danmaku
      ..comments = comments ?? this.comments;
  }

  /// 初始化
  /// todo: 需要优化
  Future<void> init() async {
    player.stream.position.listen((event) {
      if (event.inSeconds != danmakuPosition) {
        danmakuPosition = event.inSeconds;
        comments[danmakuPosition]?.asMap().forEach((index, element) async {
          await Future.delayed(
              Duration(
                  milliseconds: index *
                      1000 /
                      playSpeed ~/
                      comments[danmakuPosition]!.length), () {
            if (!showDanmaku || !player.state.playing) return;
            danmaku.addItems([element.toDanmakuItem()]);
          });
        });
      }
    });
  }
}

/// 采用 flutter_riverpod 控制视频播放、播放列表、弹幕等
class PlayController extends StateNotifier<PlayControllerState> {
  PlayController(super.state);

  /// 保存播放进度
  Future<void> saveProgress() async {
    if (state.player.state.playlist.medias.isEmpty) return;
    var progress = state.player.state.position.inMilliseconds;
    var media =
        state.player.state.playlist.medias[state.player.state.playlist.index];
    var episode = media.extras?['episode'];
    debugPrint('progress: $progress, episode: $episode');
    await state.hive.updateProgress(progress, episode);
  }

  /// 跳转
  Future<void> jump(int index, int episode) async {
    await state.player.jump(index);
    await state.player.stream.buffer.first;
    var progress = await state.hive.getProgress(episode);
    if (progress != 0) {
      await state.player.seek(Duration(milliseconds: progress));
    }
    state.hive.curEp = episode;
  }

  /// 修改播放速度
  void setSpeed(double speed) {
    state.player.setRate(speed);
    state = state.copyWith(playSpeed: speed);
  }

  /// 挂载弹幕
  void setDanmaku(DanmakuController controller) {
    state.danmaku = controller;
    state.player.danmaku = controller;
  }

  /// 切换弹幕显示状态
  void toggleDanmaku() {
    state.danmaku.clear();
    state = state.copyWith(showDanmaku: !state.showDanmaku);
  }

  @override
  bool updateShouldNotify(
    PlayControllerState old,
    PlayControllerState current,
  ) {
    return old != current;
  }

  void addDanmaku(List<DanmakuEpisodeComment> comments) {
    state.comments.clear();
    for (var element in comments) {
      if (state.comments[element.time] == null) {
        state.comments[element.time] = [];
      }
      state.comments[element.time]!.add(element);
    }
    state = state.copyWith(comments: state.comments);
  }

  Future<void> switchSubject(int value) async {
    await saveProgress();
    state.hive.switchSubject(value);
    var list = state.hive.getPlayList();
    await state.player.open(Playlist(list));
    await state.player.stream.buffer.first;
    var episode = state.hive.curEp;
    var progress = await state.hive.getProgress(episode);
    if (progress != 0) {
      await state.player.seek(Duration(milliseconds: progress));
    }
  }

  void switchSource(String value) {
    state.hive.switchSource(value);
  }
}

/// 参考自KNKPAnime，对Player进行调整
class BtPlayer extends Player {
  /// 弹幕控制器
  DanmakuController? danmaku;

  /// 构造函数
  BtPlayer();

  /// 播放
  @override
  Future<void> play() async {
    danmaku?.resume();
    await super.play();
  }

  /// 暂停
  @override
  Future<void> pause() async {
    danmaku?.pause();
    await super.pause();
  }

  /// 切换播放状态
  @override
  Future<void> playOrPause() async {
    if (super.state.playing) {
      danmaku?.pause();
    } else {
      danmaku?.resume();
    }
    await super.playOrPause();
  }

  /// 进度跳转
  @override
  Future<void> seek(Duration position) async {
    // danmaku?.clear();
    await super.seek(position);
  }

  /// 添加弹幕
  void addDanmaku(List<DanmakuEpisodeComment> comments) {
    var trans = comments.map((e) => e.toDanmakuItem()).toList();
    var map = <int, List<DanmakuItem>>{};
    for (var element in trans) {
      if (map[element.time] == null) {
        map[element.time] = [];
      }
      map[element.time]!.add(element);
    }
    for (var element in map.entries) {
      Future.delayed(Duration(milliseconds: element.key * 1000), () {
        if (state.playing) {
          danmaku?.addItems(element.value);
        }
      });
    }
    danmaku?.resume();
  }
}
