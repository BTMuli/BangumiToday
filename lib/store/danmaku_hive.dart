// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:hive/hive.dart';

// Project imports:
import '../models/hive/danmaku_model.dart';

/// Bangumi Subject与DandanPlay弹幕关联
class DanmakuHive extends ChangeNotifier {
  /// 单实例
  DanmakuHive._();

  static final DanmakuHive instance = DanmakuHive._();

  /// 获取实例
  factory DanmakuHive() => instance;

  /// 获取 Box
  static Box<DanmakuHiveModel> get box => Hive.box<DanmakuHiveModel>('danmaku');

  /// 获取所有值
  List<DanmakuHiveModel> get all => box.values.toList();

  /// 查找subject对应的信息
  DanmakuHiveModel? find(int subjectId) {
    var find = all.indexWhere((e) => e.subjectId == subjectId);
    if (find == -1) return null;
    return all[find];
  }

  /// 添加
  Future<void> add(DanmakuHiveModel model) async {
    var find = all.indexWhere((e) => e == model);
    if (find != -1) return;
    await box.add(model);
    notifyListeners();
  }

  /// 删除
  Future<void> delete(DanmakuHiveModel model) async {
    var find = all.indexWhere((e) => e == model);
    if (find == -1) return;
    await box.deleteAt(find);
    notifyListeners();
  }

  /// 更新-通过subjectId
  Future<void> update(int subjectId, DanmakuHiveModel model) async {
    var find = all.indexWhere((e) => e.subjectId == subjectId);
    if (find == -1) return;
    await box.putAt(find, model);
    notifyListeners();
  }

  /// 展示信息
  Future<void> showInfo(BuildContext context, DanmakuHiveModel data) async {
    await showDialog(
      barrierDismissible: true,
      context: context,
      builder: (context) => ContentDialog(
        title: const Text('Subject-Danmaku Info'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('SubjectId: ${data.subjectId}'),
            Text('AnimeId: ${data.animeId}'),
            Text('AnimeTitle: ${data.animeTitle}'),
          ],
        ),
      ),
    );
  }
}
