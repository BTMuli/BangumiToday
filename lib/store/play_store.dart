// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';

/// 播放列表提供者
final playStoreProvider = ChangeNotifierProvider<BtPlayStore>((ref) {
  return BtPlayStore();
});

/// 播放列表
class BtPlayStore extends ChangeNotifier {
  /// 播放列表
  final List<Media> _list = [];

  /// 获取播放列表
  List<Media> get list => _list;

  /// 添加播放任务
  bool addTask(Media media) {
    /// 判断是否已经存在
    var find = _list.indexWhere((e) => e == media);
    if (find != -1) {
      return false;
    }
    _list.add(media);
    notifyListeners();
    return true;
  }

  /// 移除播放任务
  void removeTask(Media media) {
    _list.removeWhere((e) => e == media);
    notifyListeners();
  }
}
