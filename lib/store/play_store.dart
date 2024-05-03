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
  int index = 0;

  /// 获取当前播放
  PlayHiveModel get current => box.getAt(index)!;

  /// 获取所有播放
  List<PlayHiveModel> get all => box.values.toList();

  /// 获取所有播放媒体
  List<Media> get allMedia => box.values
      .map((e) => Media(e.file, extras: {'subject': e.subjectId}))
      .toList();

  /// 事件

  /// 添加播放
  Future<void> add(String file, int subject) async {
    var model = PlayHiveModel(file: file, subjectId: subject);
    var find = box.values.toList().indexWhere((e) => e == model);
    if (find != -1) {
      index = find;
      return;
    }
    await box.add(model);
    index = box.length - 1;
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
  Future<void> updateProgress(int progress, {String? file}) async {
    current.progress = progress;
    if (file != null) {
      var find = box.values.toList().indexWhere((e) => e.file == file);
      if (find != -1) {
        await box.putAt(find, current);
      }
    } else {
      await box.putAt(index, current);
    }
    notifyListeners();
  }

  void jump(PlayHiveModel model) {
    var find = box.values.toList().indexWhere((e) => e == model);
    if (find == -1 || find == index) return;
    index = find;
    notifyListeners();
  }
}
