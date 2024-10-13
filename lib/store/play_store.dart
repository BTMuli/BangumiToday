// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:hive/hive.dart';
import 'package:media_kit/media_kit.dart';

// Project imports:
import '../models/hive/play_model.dart';
import '../tools/log_tool.dart';

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
  PlayHiveModel? curModel;

  /// 当前播放索引，搭配最近播放条目使用
  late String curEp;

  /// 初始化
  void init() {
    if (values.isEmpty) return;
    values.sort((a, b) => a.subjectId.compareTo(b.subjectId));
    for (var element in values) {
      element.items.sort((a, b) => a.episode.compareTo(b.episode));
    }
    var playable = getPlayable();
    if (playable.isNotEmpty) {
      curModel = playable[0];
    } else {
      curModel = values[0];
    }
    curEp = curModel!.items[0].episode;
  }

  /// open，打开某条目的播放
  Future<void> open({int? subject}) async {
    PlayHiveModel model;
    if (subject != null) {
      curModel = box.get(subject) ?? values[0];
    } else {
      curModel = values[0];
    }
    model = curModel!;
    if (model.items.isNotEmpty) {
      curEp = model.items[0].episode;
    }
    notifyListeners();
  }

  /// 判断-是否播放列表为空
  Future<bool> isPlayable({int? subject}) async {
    if (subject == null || curModel == null) return false;
    var model = box.get(subject);
    if (model == null) return false;
    return model.cutRegex.isNotEmpty;
  }

  /// 获取所有播放列表非空的model
  List<PlayHiveModel> getPlayable() {
    var res = <PlayHiveModel>[];
    for (var model in values) {
      if (model.playList.isNotEmpty) {
        res.add(model);
      }
    }
    return res;
  }

  /// 根据播放链接获取播放进度
  Future<int> getProgressByFilePath(String link) async {
    if (curModel == null) return 0;
    var sourceFind = curModel!.items.indexWhere((e) => e.file == link);
    if (sourceFind == -1) return 0;
    return curModel!.items[sourceFind].progress;
  }

  /// 获取播放进度
  Future<int> getProgress(String index, {int? subject}) async {
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
      model = curModel ?? values[0];
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
  Future<void> addPlayItem(
    String file,
    int subject,
    String index, {
    bool play = true,
    String cutRegex = '',
  }) async {
    PlayHiveItem item = PlayHiveItem(episode: index, progress: 0);
    PlayHiveModel model = PlayHiveModel(
      subjectId: subject,
      items: [item],
      cutRegex: cutRegex,
    );
    await box.put(subject, model);
    if (play) {
      curModel = model;
      curEp = index;
    }
    notifyListeners();
  }

  /// 添加BMF播放配置
  Future<void> addBmf(
    String file,
    int subject,
    String index, {
    bool play = true,
  }) async {
    var model = box.get(subject);
    if (model == null) {
      await addPlayItem(file, subject, index, play: play);
      return;
    }
    // 查找是否有播放项
    var playFind = model.items.indexWhere((e) => e.episode == index);
    if (playFind == -1) {
      PlayHiveItem item = PlayHiveItem(episode: index, progress: 0);
      model.items.add(item);
    }
    if (play) {
      curModel = model;
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
    } else if (values.isEmpty || curModel == null) {
      return [];
    } else {
      model = curModel!;
    }
    var sourceFind = model.items.indexWhere((e) => e.episode == curEp);
    if (sourceFind == -1) return [];
    var playListGet = model.playList;

    /// 将跟curEp相同的放到第一个
    var findIndex = playListGet.indexWhere((e) => e == curEp);
    if (findIndex != -1) {
      var item = playListGet.removeAt(findIndex);
      playListGet.insert(0, item);
    }
    List<Media> res = [];
    for (var item in playListGet) {
      var epFind = model.items.indexWhere((e) => e.episode == item);
      if (epFind == -1) continue;
      var playItem = model.items[epFind];
      res.add(Media(playItem.file, extras: {'episode': playItem.episode}));
    }
    model.playList = playListGet;
    return res;
  }

  /// 删除播放
  Future<void> delete(int subject) async {
    await box.delete(subject);
    notifyListeners();
  }

  /// 更新当前播放进度
  Future<void> updateProgress(int progress, int index) async {
    var model = curModel;
    if (model == null) return;
    var find = model.items.indexWhere((e) => e.episode == curEp);
    if (find == -1) return;
    model.items[find].progress = progress;
    BTLogTool.info('更新进度: $progress');
    await box.put(model.subjectId, model);
  }

  /// 跳转
  void jump(String episode, {int? subject}) {
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

  String? getEpByPath(int subject, String filePath) {
    var model = box.get(subject);
    if (model == null) return null;
    var find = model.items.indexWhere((e) => e.file == filePath);
    if (find == -1) return null;
    return model.items[find].episode;
  }

  /// 删除播放进度
  Future<void> deleteProgress(int subjectId, {String? episode}) async {
    var model = box.get(subjectId);
    if (model == null) return;
    if (episode == null) {
      model.items.clear();
    } else {
      model.items.removeWhere((element) => element.episode == episode);
    }
    await box.put(subjectId, model);
    notifyListeners();
  }

  /// 删除BMF
  Future<void> deletePlayItem(int subjectId, String episode) async {
    var model = box.get(subjectId);
    if (model == null) return;
    var epFind = model.playList.indexWhere((e) => e == episode);
    if (epFind != -1) {
      model.playList.removeAt(epFind);
    }
    await box.put(subjectId, model);
    notifyListeners();
  }

  /// 删除播放历史
  Future<void> deleteHistory(int subjectId) async {
    await box.delete(subjectId);
    notifyListeners();
  }

  void switchSubject(int value) {
    curModel = box.get(value);
    var list = getPlayList(subject: value);
    if (list.isNotEmpty) {
      curEp = list[0].extras?['episode'];
    }
    notifyListeners();
  }

  Future<void> updateTitle(int subject, String title) async {
    var model = box.get(subject);
    if (model == null) return;
    model.subjectName = title;
    await box.put(subject, model);
    notifyListeners();
  }

  /// 更新切削正则
  Future<void> updateCutRegex(int subject, String cutRegex) async {
    var model = box.get(subject);
    if (model == null) return;
    model.cutRegex = cutRegex;
    await box.put(subject, model);
    notifyListeners();
  }

  Future<void> updateItem(PlayHiveModel item) async {
    await box.put(item.subjectId, item);
    notifyListeners();
  }

  String getSubjectName(int subject) {
    var model = box.get(subject);
    if (model == null) return '';
    return model.subjectName;
  }
}
