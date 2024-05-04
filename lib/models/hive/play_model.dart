// Package imports:
import 'package:hive/hive.dart';

/// 视频播放的 Hive 模型
class PlayHiveModel {
  /// 视频地址
  final String file;

  /// 对应条目
  final int subjectId;

  /// 播放进度
  late int progress;

  /// 是否自动播放
  late bool autoPlay;

  /// 构造
  PlayHiveModel({
    required this.file,
    required this.subjectId,
    this.progress = 0,
    this.autoPlay = true,
  });
}

/// 播放的 Hive 适配器
class PlayHiveAdapter extends TypeAdapter<PlayHiveModel> {
  @override
  final int typeId = 4;

  @override
  PlayHiveModel read(BinaryReader reader) {
    return PlayHiveModel(
      file: reader.readString(),
      subjectId: reader.readInt(),
      progress: reader.readInt(),
      autoPlay: reader.readBool(),
    );
  }

  @override
  void write(BinaryWriter writer, PlayHiveModel obj) {
    writer.writeString(obj.file);
    writer.writeInt(obj.subjectId);
    writer.writeInt(obj.progress);
    writer.writeBool(obj.autoPlay);
  }
}
