// Package imports:
import 'package:dart_rss/dart_rss.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../models/hive/dtt_model.dart';

// import 'package:hive/hive.dart';

/// 下载状态提供者
final dttStoreProvider = ChangeNotifierProvider<BtDttStore>((ref) {
  /// 从hive中读取下载列表
  // var items = Hive.box<DttItem>('dttItems');
  // return BtDttStore().._list.addAll(items.values.toList());
  return BtDttStore();
});

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
    // Hive.box<DttItem>('dttItems').put(item.link, DttItem(item, dir));
    notifyListeners();
    return true;
  }

  /// 移除下载任务
  void removeTask(RssItem item) {
    _list.removeWhere((e) => e.item == item);
    // Hive.box<DttItem>('dttItems').delete(item.link);
    notifyListeners();
  }
}
