// Package imports:
import 'package:dart_rss/dart_rss.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

// Project imports:
import '../models/hive/dtt_model.dart';

/// 下载状态提供者
final dttStoreProvider = ChangeNotifierProvider<DttHive>((ref) {
  /// 从hive中读取下载列表
  var items = Hive.box<DttHiveModel>('dtt');
  return DttHive().._list.addAll(items.values.toList());
});

/// 下载状态
class DttHive extends ChangeNotifier {
  /// 下载列表，这边只存储RssItem跟下载目录
  final List<DttHiveModel> _list = [];

  /// 获取下载列表
  List<DttHiveModel> get list => _list;

  /// 添加下载任务
  bool addTask(RssItem item, String dir) {
    var miniItem = MiniRssItem(item.title ?? '', item.enclosure?.url ?? '');

    /// 判断是否已经存在
    var find = _list.indexWhere((e) => e.item == miniItem);
    if (find != -1) {
      return false;
    }
    _list.add(DttHiveModel(miniItem, dir));
    Hive.box<DttHiveModel>('dtt').put(item.link, DttHiveModel(miniItem, dir));
    notifyListeners();
    return true;
  }

  /// 移除下载任务
  void removeTask(MiniRssItem item) {
    _list.removeWhere((e) => e.item == item);
    Hive.box<DttHiveModel>('dtt').delete(item.link);
    notifyListeners();
  }
}
