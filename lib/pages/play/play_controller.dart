// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

// Project imports:
import '../../../store/play_store.dart';

/// Provider
final playControllerProvider =
    StateNotifierProvider<PlayController, PlayControllerState>(
  (ref) => PlayController(PlayControllerState()),
);

class PlayControllerState {
  /// hive，用于存储播放列表&播放进度
  late PlayHive hive = PlayHive();

  /// Player
  late Player player = Player();

  /// PlayerController
  late VideoController video = VideoController(player);

  /// 播放速度
  double playSpeed = 1.0;

  /// copyWith
  PlayControllerState copyWith({
    PlayHive? hive,
    Player? player,
    VideoController? video,
    double? playSpeed,
  }) {
    return PlayControllerState()
      ..player = player ?? this.player
      ..playSpeed = playSpeed ?? this.playSpeed
      ..video = video ?? this.video;
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
  Future<void> jump(int index, String episode) async {
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

  @override
  bool updateShouldNotify(
    PlayControllerState old,
    PlayControllerState current,
  ) {
    return old != current;
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
}
