// Package imports:
import 'package:hive/hive.dart';

/// torrent tracker的HiVe模型
class TrackerHiveModel {
  /// 地址
  final String url;

  /// 更新时间，yyyy-MM-dd
  late String updateTime;

  /// trackerList
  List<String> trackerList = [];

  /// 构造
  TrackerHiveModel({
    required this.url,
    required this.updateTime,
    required this.trackerList,
  });
}

/// trackerHive的适配器
class TrackerHiveAdapter extends TypeAdapter<TrackerHiveModel> {
  @override
  final int typeId = 3;

  @override
  TrackerHiveModel read(BinaryReader reader) {
    return TrackerHiveModel(
      url: reader.readString(),
      updateTime: reader.readString(),
      trackerList: reader.readList().cast<String>(),
    );
  }

  @override
  void write(BinaryWriter writer, TrackerHiveModel obj) {
    writer.writeString(obj.url);
    writer.writeString(obj.updateTime);
    writer.writeList(obj.trackerList);
  }
}
