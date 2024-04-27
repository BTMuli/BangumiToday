// Package imports:
import 'package:dart_rss/dart_rss.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 下载状态提供者
final dttStoreProvider = ChangeNotifierProvider<BtDttStore>((ref) {
  return BtDttStore();
});

/// 下载列表
class DttItem {
  /// RssItem
  final RssItem item;

  /// 下载目录
  final String dir;

  /// 构造函数
  DttItem(this.item, this.dir);
}

/// 下载状态
class BtDttStore extends ChangeNotifier {
  /// 下载列表，这边只存储RssItem跟下载目录
  final List<DttItem> _list = [];

  /// 获取下载列表
  List<DttItem> get list => _list;

  /// 添加下载任务
  bool addTask(RssItem item, String dir) {
    /// 判断是否已经存在
    var find = _list.indexWhere((e) => e.item == item);
    if (find != -1) {
      return false;
    }
    _list.add(DttItem(item, dir));
    notifyListeners();
    return true;
  }

  /// 移除下载任务
  void removeTask(RssItem item) {
    _list.removeWhere((e) => e.item == item);
    notifyListeners();
  }
}
