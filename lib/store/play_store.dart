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
  late PlayHiveModel? curModel;

  /// 当前资源名称
  late String curSource;

  /// 当前播放索引，搭配最近播放条目使用
  late int curEp;

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
    var sourceFind = curModel!.sources.indexWhere((e) => e.items.isNotEmpty);
    if (sourceFind == -1) {
      curSource = curModel!.sources[0].source;
    } else {
      curSource = curModel!.sources[sourceFind].source;
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
    if (model.sources.isNotEmpty) {
      curSource = model.sources[0].source;
    }
    if (model.items.isNotEmpty) {
      curEp = model.items[0].episode;
    }
    notifyListeners();
  }

  /// 判断-是否播放列表为空
  Future<bool> isPlayable({int? subject}) async {
    if (subject == null) {
      if (curModel == null) return false;
      return curModel!.sources.isNotEmpty;
    }
    var model = box.get(subject);
    if (model == null) return false;
    return model.sources.isNotEmpty;
  }

  /// 获取所有播放列表非空的model
  List<PlayHiveModel> getPlayable() {
    var res = <PlayHiveModel>[];
    for (var model in values) {
      if (model.sources.isEmpty) continue;
      if (model.sources.every((e) => e.items.isEmpty)) continue;
      res.add(model);
    }
    return res;
  }

  /// 根据播放链接获取播放进度
  Future<int> getProgressByLink(String link) async {
    var model = curModel;
    if (model == null) return 0;
    var sourceFind = model.sources.indexWhere((e) => e.source == curSource);
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
  Future<void> addBmfNew(
    String file,
    int subject,
    int index, {
    bool play = true,
  }) async {
    PlayHiveSource bmf = PlayHiveSource(
      source: "BMF",
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
      curSource = "BMF";
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
    var sourceFind = model.sources.indexWhere((e) => e.source == "BMF");
    if (sourceFind == -1) {
      PlayHiveSource bmf = PlayHiveSource(
        source: "BMF",
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
      curSource = "BMF";
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
    var sourceFind = model.sources.indexWhere((e) => e.source == curSource);
    if (sourceFind == -1) return [];
    var source = model.sources[sourceFind];
    source.items.sort((a, b) => a.index.compareTo(b.index));
    // 将跟curEp相同的放到第一个
    var find = source.items.indexWhere((e) => e.index == curEp);
    if (find != -1) {
      var item = source.items.removeAt(find);
      source.items.insert(0, item);
    }
    return source.items.map((e) {
      return Media(e.link, extras: {'episode': e.index});
    }).toList();
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
    var sourceIndex = model.sources.indexWhere((e) => e.source == "BMF");
    if (sourceIndex == -1) return null;
    var source = model.sources[sourceIndex];
    var find = source.items.indexWhere((e) => e.link == filePath);
    if (find == -1) return null;
    return model.sources[sourceIndex].items[find].index;
  }

  /// 删除播放进度
  Future<void> deleteProgress(int subjectId, {int? episode}) async {
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

  /// 删除资源
  Future<void> deleteSource(int subjectId, {String? source}) async {
    var model = box.get(subjectId);
    if (model == null) return;
    model.sources.removeWhere((element) => element.source == source);
    await box.put(subjectId, model);
    notifyListeners();
  }

  /// 删除BMF
  Future<void> deleteBMF(int subjectId, int episode) async {
    var model = box.get(subjectId);
    if (model == null) return;
    var sourceIndex = model.sources.indexWhere((e) => e.source == "BMF");
    if (sourceIndex == -1) return;
    var source = model.sources[sourceIndex];
    source.items.removeWhere((element) => element.index == episode);
    await box.put(subjectId, model);
    notifyListeners();
  }

  void switchSubject(int value) {
    curModel = box.get(value);
    curSource = curModel!.sources[0].source;
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

  Future<void> updateItem(PlayHiveModel item) async {
    await box.put(item.subjectId, item);
    notifyListeners();
  }

  String getSubjectName(int subject) {
    var model = box.get(subject);
    if (model == null) return '';
    return model.subjectName;
  }

  void switchSource(String value) {
    curSource = value;
    notifyListeners();
  }
}
