// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:hive/hive.dart';
import 'package:media_kit/media_kit.dart';

// Project imports:
import '../models/hive/play_model.dart';

/// 播放记录的Hive模型
class PlayHive extends ChangeNotifier {
  /// 单实例
  PlayHive._();

  static final PlayHive instance = PlayHive._();

  /// 获取实例
  factory PlayHive() => instance;

  /// 获取 Box
  static Box<PlayHiveModel> get box => Hive.box<PlayHiveModel>('play');

  /// 获取所有值
  List<PlayHiveModel> get values => box.values.toList();

  /// 最近播放条目
  late PlayHiveModel curModel;

  /// 当前资源名称
  late VideoSourceType curSource;

  /// 当前播放索引，搭配最近播放条目使用
  late int curEp;

  /// open，打开某条目的播放
  Future<void> open({int? subject}) async {
    PlayHiveModel model;
    if (subject != null) {
      curModel = box.get(subject) ?? values[0];
    } else {
      curModel = values[0];
    }
    model = curModel;
    if (model.sources.isNotEmpty) {
      curSource = model.sources[0].sourceType;
    }
    if (model.items.isNotEmpty) {
      curEp = model.items[0].episode;
    }
    notifyListeners();
  }

  /// 根据播放链接获取播放进度
  Future<int> getProgressByLink(String link) async {
    var model = curModel;
    var sourceFind = model.sources.indexWhere((e) => e.sourceType == curSource);
    if (sourceFind == -1) return 0;
    var itemFind = model.sources[sourceFind].items.indexWhere(
      (e) => e.link == link,
    );
    if (itemFind == -1) return 0;
    var episode = model.sources[sourceFind].items[itemFind].index;
    var playFind = model.items.indexWhere((e) => e.episode == episode);
    if (playFind == -1) return 0;
    return model.items[playFind].progress;
  }

  /// 获取播放进度
  Future<int> getProgress(int index, {int? subject}) async {
    PlayHiveModel model;
    if (subject != null) {
      var get = box.get(subject);
      if (get == null) {
        var newModel = PlayHiveModel(subjectId: subject, items: []);
        var episode = PlayHiveItem(episode: index, progress: 0);
        newModel.items.add(episode);
        await box.put(subject, newModel);
        return 0;
      }
      model = get;
    } else {
      model = curModel;
    }
    var find = model.items.indexWhere((e) => e.episode == index);
    if (find == -1) {
      var episode = PlayHiveItem(episode: index, progress: 0);
      model.items.add(episode);
      return 0;
    }
    return model.items[find].progress;
  }

  /// 添加BMF播放配置-新
  Future<void> addBmfNew(
    String file,
    int subject,
    int index, {
    bool play = true,
  }) async {
    PlayHiveSource bmf = PlayHiveSource(
      sourceType: VideoSourceType.bmf,
      items: [PlayHiveSourceItem(link: file, index: index)],
    );
    PlayHiveItem item = PlayHiveItem(episode: index, progress: 0);
    PlayHiveModel model = PlayHiveModel(
      subjectId: subject,
      items: [item],
      sources: [bmf],
    );
    await box.put(subject, model);
    if (play) {
      curModel = model;
      curSource = VideoSourceType.bmf;
      curEp = index;
    }
    notifyListeners();
  }

  /// 添加BMF播放配置
  Future<void> addBmf(
    String file,
    int subject,
    int index, {
    bool play = true,
  }) async {
    var model = box.get(subject);
    if (model == null) {
      await addBmfNew(file, subject, index, play: play);
      return;
    }
    // 查找是否有BMF资源
    var sourceFind = model.sources.indexWhere(
      (e) => e.sourceType == VideoSourceType.bmf,
    );
    if (sourceFind == -1) {
      PlayHiveSource bmf = PlayHiveSource(
        sourceType: VideoSourceType.bmf,
        items: [PlayHiveSourceItem(link: file, index: index)],
      );
      model.sources.add(bmf);
    } else {
      var source = model.sources[sourceFind];
      // 查找是否有播放项
      var playFind = source.items.indexWhere((e) => e.index == index);
      if (playFind == -1) {
        PlayHiveSourceItem item = PlayHiveSourceItem(link: file, index: index);
        source.items.add(item);
      }
    }
    // 查找是否有播放项
    var playFind = model.items.indexWhere((e) => e.episode == index);
    if (playFind == -1) {
      PlayHiveItem item = PlayHiveItem(episode: index, progress: 0);
      model.items.add(item);
    }
    if (play) {
      curModel = model;
      curSource = VideoSourceType.bmf;
      curEp = index;
    }
    await box.put(subject, model);
    notifyListeners();
  }

  /// 获取当前播放列表
  List<Media> getPlayList({int? subject}) {
    PlayHiveModel model;
    if (subject != null) {
      var get = box.get(subject);
      if (get == null) return [];
      model = get;
    } else {
      model = curModel;
    }
    var sourceFind = model.sources.indexWhere((e) => e.sourceType == curSource);
    if (sourceFind == -1) return [];
    var source = model.sources[sourceFind];
    return source.items.map((e) {
      return Media(e.link, extras: {'episode': e.index});
    }).toList();
  }

  /// 删除播放
  Future<void> delete(PlayHiveModel model) async {
    // todo 暂不支持
    return;
    // notifyListeners();
  }

  /// 更新当前播放进度
  Future<void> updateProgress(int progress, {int? index}) async {
    var model = curModel;
    int find;
    if (index != null) {
      find = model.items.indexWhere((e) => e.episode == index);
    } else {
      find = model.items.indexWhere((e) => e.episode == curEp);
    }
    if (find == -1) return;
    model.items[find].progress = progress;
    await box.put(model.subjectId, model);
  }

  /// 跳转
  void jump(int episode, {int? subject}) {
    if (subject != null) {
      var model = box.get(subject);
      if (model == null) return;
      curModel = model;
      curEp = episode;
    } else {
      curEp = episode;
    }
    notifyListeners();
  }

  int? getBmfEpisode(int subject, String filePath) {
    var model = box.get(subject);
    if (model == null) return null;
    var sourceIndex = model.sources.indexWhere(
      (e) => e.sourceType == VideoSourceType.bmf,
    );
    if (sourceIndex == -1) return null;
    var source = model.sources[sourceIndex];
    var find = source.items.indexWhere((e) => e.link == filePath);
    if (find == -1) return null;
    return model.sources[sourceIndex].items[find].index;
  }

  int getNextBmfEpisode(int subject) {
    var model = box.get(subject);
    if (model == null) return 0;
    var sourceIndex = model.sources.indexWhere(
      (e) => e.sourceType == VideoSourceType.bmf,
    );
    if (sourceIndex == -1) return 0;
    var max = 0;
    for (var item in model.sources[sourceIndex].items) {
      if (item.index > max) max = item.index;
    }
    return max + 1;
  }
}
