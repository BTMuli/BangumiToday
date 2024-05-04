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

  /// 当前索引
  late int index = 0;

  /// 获取所有播放
  List<PlayHiveModel> get all => box.values.toList();

  /// 获取所有播放媒体
  List<Media> get allMedia => box.values.map((e) => Media(e.file)).toList();

  /// 获取指定文件的播放进度
  int getProgress(int index) {
    if (index < 0 || index >= box.values.length) return 0;
    return box.values.toList()[index].progress;
  }

  /// 添加播放
  Future<void> add(String file, int subject, {bool play = true}) async {
    var model = PlayHiveModel(file: file, subjectId: subject, autoPlay: play);
    var find = box.values.toList().indexWhere((e) => e.file == model.file);
    if (find != -1) {
      index = find;
      box.values.toList()[index].autoPlay = play;
      notifyListeners();
      return;
    }
    await box.add(model);
    if (play) index = box.length - 1;
    notifyListeners();
  }

  /// 删除播放
  Future<void> delete(PlayHiveModel model) async {
    var find = box.values.toList().indexWhere((e) => e == model);
    if (find == -1) return;
    if (find < index) {
      index -= 1;
    } else if (find == index) {
      index = 0;
    }
    await box.deleteAt(find);
    notifyListeners();
  }

  /// 更新当前播放进度
  Future<void> updateProgress(int progress, int index) async {
    if (index < 0 || index >= box.length) return;
    var model = box.getAt(index)!;
    model.progress = progress;
    await box.putAt(index, model);
  }

  /// 跳转
  void jump(PlayHiveModel model) {
    var find = box.values.toList().indexWhere((e) => e == model);
    if (find == -1) return;
    index = find;
    box.values.toList()[index].autoPlay = true;
    notifyListeners();
  }

  /// 删除无用数据
  Future<int> deleteUseless(List<Media> files) async {
    var remove = <PlayHiveModel>[];
    var list = box.values.toList();
    for (var i = 0; i < list.length; i++) {
      if (!files.contains(Media(list[i].file))) {
        remove.add(list[i]);
      }
    }
    var cnt = remove.length;
    if (cnt == 0) return 0;
    for (var i = 0; i < cnt; i++) {
      await delete(remove[i]);
    }
    return cnt;
  }

  /// 调整播放顺序
  Future<void> putFirst(int index) async {
    if (index < 0 || index >= box.length) return;
    var model = box.getAt(index)!;
    await box.deleteAt(index);
    await box.putAt(0, model);
    this.index = 0;
  }
}
