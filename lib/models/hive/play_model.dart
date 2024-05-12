// Package imports:
import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';

/// 视频源类型枚举
@JsonEnum(valueField: 'value')
enum VideoSourceType {
  /// 本地
  local(0),

  /// 网络
  network(1);

  final int value;

  const VideoSourceType(this.value);
}

/// 视频播放的 Hive 模型
class PlayHiveModel {
  /// 视频源类型
  late VideoSourceType sourceType;

  /// 视频地址
  /// 当 [sourceType] 为 [VideoSourceType.local] 时，为本地文件路径
  /// 当 [sourceType] 为 [VideoSourceType.network] 时，为网络地址
  final String path;

  /// 对应条目
  final int subjectId;

  /// bangumi的章节id
  late int episodeId;

  /// 弹幕id
  late int? danmakuId;

  /// 播放进度
  late int progress;

  /// 是否自动播放
  late bool autoPlay;

  /// 构造
  PlayHiveModel({
    this.sourceType = VideoSourceType.local,
    required this.path,
    required this.subjectId,
    this.episodeId = -1,
    this.danmakuId,
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
      sourceType: VideoSourceType.values[reader.readInt()],
      path: reader.readString(),
      subjectId: reader.readInt(),
      episodeId: reader.readInt(),
      danmakuId: reader.readInt(),
      progress: reader.readInt(),
      autoPlay: reader.readBool(),
    );
  }

  @override
  void write(BinaryWriter writer, PlayHiveModel obj) {
    writer.writeInt(obj.sourceType.index);
    writer.writeString(obj.path);
    writer.writeInt(obj.subjectId);
    writer.writeInt(obj.episodeId);
    if (obj.danmakuId != null) writer.writeInt(obj.danmakuId!);
    writer.writeInt(obj.progress);
    writer.writeBool(obj.autoPlay);
  }
}
