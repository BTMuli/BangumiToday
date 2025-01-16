// Package imports:
import 'package:hive/hive.dart';

/// 下载列表
class DttHiveModel {
  /// RssItem
  final MiniRssItem item;

  /// 下载目录
  final String dir;

  /// 构造函数
  DttHiveModel(this.item, this.dir);
}

/// 下载列表的适配器
class DttItemAdapter extends TypeAdapter<DttHiveModel> {
  @override
  final int typeId = 1;

  @override
  DttHiveModel read(BinaryReader reader) {
    var item = reader.read() as MiniRssItem;
    var dir = reader.read() as String;
    return DttHiveModel(item, dir);
  }

  @override
  void write(BinaryWriter writer, DttHiveModel obj) {
    writer.write(obj.item);
    writer.write(obj.dir);
  }
}

/// MiniRssItem
class MiniRssItem {
  /// 标题
  final String title;

  /// 链接
  final String link;

  /// 构造函数
  MiniRssItem(this.title, this.link);
}

/// rssItem的适配器
class RssItemAdapter extends TypeAdapter<MiniRssItem> {
  @override
  final int typeId = 4;

  @override
  MiniRssItem read(BinaryReader reader) {
    var title = reader.read() as String;
    var link = reader.read() as String;
    return MiniRssItem(title, link);
  }

  @override
  void write(BinaryWriter writer, MiniRssItem obj) {
    writer.write(obj.title);
    writer.write(obj.link);
  }
}
