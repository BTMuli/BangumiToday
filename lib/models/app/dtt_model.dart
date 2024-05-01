// Package imports:
import 'package:dart_rss/domain/rss_item.dart';
import 'package:hive/hive.dart';

/// 下载列表
class DttItem {
  /// RssItem
  final RssItem item;

  /// 下载目录
  final String dir;

  /// 构造函数
  DttItem(this.item, this.dir);
}

/// 下载列表的适配器
class DttItemAdapter extends TypeAdapter<DttItem> {
  @override
  final int typeId = 1;

  @override
  DttItem read(BinaryReader reader) {
    var item = reader.read() as RssItem;
    var dir = reader.read() as String;
    return DttItem(item, dir);
  }

  @override
  void write(BinaryWriter writer, DttItem obj) {
    writer.write(obj.item);
    writer.write(obj.dir);
  }
}
