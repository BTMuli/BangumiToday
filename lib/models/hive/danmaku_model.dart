// Package imports:
import 'package:hive/hive.dart';

/// BangumiSubject与DandanPlay弹幕关联的Hive模型
class DanmakuHiveModel {
  /// subjectId
  final int subjectId;

  /// animeId
  late int animeId;

  /// animeTitle
  late String animeTitle;

  /// 构造函数
  DanmakuHiveModel({
    required this.subjectId,
    required this.animeId,
    this.animeTitle = '',
  });
}

/// DanmakuHive的适配器
class DanmakuHiveAdapter extends TypeAdapter<DanmakuHiveModel> {
  @override
  final int typeId = 8;

  @override
  DanmakuHiveModel read(BinaryReader reader) {
    var subjectId = reader.readInt();
    var animeId = reader.readInt();
    var animeTitle = reader.readString();
    return DanmakuHiveModel(
      subjectId: subjectId,
      animeId: animeId,
      animeTitle: animeTitle,
    );
  }

  @override
  void write(BinaryWriter writer, DanmakuHiveModel obj) {
    writer.writeInt(obj.subjectId);
    writer.writeInt(obj.animeId);
    writer.writeString(obj.animeTitle);
  }
}
