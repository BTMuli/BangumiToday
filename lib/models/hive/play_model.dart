// Package imports:
import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';

/// 视频源类型枚举
@JsonEnum(valueField: 'value')
enum VideoSourceType {
  /// BMF
  bmf(0),

  /// 其他
  other(1);

  final int value;

  const VideoSourceType(this.value);
}

extension VideoSourceTypeExtension on VideoSourceType {
  String get label {
    switch (this) {
      case VideoSourceType.bmf:
        return 'BMF';
      case VideoSourceType.other:
        return '其他';
    }
  }
}

/// 播放资源项
class PlayHiveSourceItem {
  /// 资源路径
  final String link;

  /// 索引，用于辨别集数
  final int index;

  /// 构造
  PlayHiveSourceItem({
    required this.link,
    required this.index,
  });
}

/// 播放资源项的Hive适配器
class PlayHiveSourceItemAdapter extends TypeAdapter<PlayHiveSourceItem> {
  @override
  final int typeId = 7;

  @override
  PlayHiveSourceItem read(BinaryReader reader) {
    return PlayHiveSourceItem(
      link: reader.readString(),
      index: reader.readInt(),
    );
  }

  @override
  void write(BinaryWriter writer, PlayHiveSourceItem obj) {
    writer.writeString(obj.link);
    writer.writeInt(obj.index);
  }
}

/// 播放资源
class PlayHiveSource {
  /// 资源类型
  final VideoSourceType sourceType;

  /// 资源列表
  List<PlayHiveSourceItem> items;

  /// 构造
  PlayHiveSource({
    required this.sourceType,
    required this.items,
  });
}

/// 播放资源的Hive适配器
class PlayHiveSourceAdapter extends TypeAdapter<PlayHiveSource> {
  @override
  final int typeId = 6;

  @override
  PlayHiveSource read(BinaryReader reader) {
    return PlayHiveSource(
      sourceType: VideoSourceType.values[reader.readInt()],
      items: reader.readList().cast<PlayHiveSourceItem>(),
    );
  }

  @override
  void write(BinaryWriter writer, PlayHiveSource obj) {
    writer.writeInt(obj.sourceType.value);
    writer.writeList(obj.items);
  }
}

/// 同条目的播放项
class PlayHiveItem {
  /// 集数
  late int episode;

  /// 播放进度
  late int progress;

  /// 构造
  PlayHiveItem({
    this.episode = 0,
    this.progress = 0,
  });
}

/// 播放项的Hive适配器
class PlayHiveItemAdapter extends TypeAdapter<PlayHiveItem> {
  @override
  final int typeId = 5;

  @override
  PlayHiveItem read(BinaryReader reader) {
    return PlayHiveItem(
      episode: reader.readInt(),
      progress: reader.readInt(),
    );
  }

  @override
  void write(BinaryWriter writer, PlayHiveItem obj) {
    writer.writeInt(obj.episode);
    writer.writeInt(obj.progress);
  }
}

/// 视频播放的 Hive 模型
class PlayHiveModel {
  /// 对应条目
  final int subjectId;

  /// 子章节
  late List<PlayHiveItem> items;

  /// 资源列表
  late List<PlayHiveSource> sources;

  /// 构造
  PlayHiveModel({
    required this.subjectId,
    this.items = const [],
    this.sources = const [],
  });
}

/// 播放的 Hive 适配器
class PlayHiveAdapter extends TypeAdapter<PlayHiveModel> {
  @override
  final int typeId = 4;

  @override
  PlayHiveModel read(BinaryReader reader) {
    return PlayHiveModel(
      subjectId: reader.readInt(),
      items: reader.readList().cast<PlayHiveItem>(),
      sources: reader.readList().cast<PlayHiveSource>(),
    );
  }

  @override
  void write(BinaryWriter writer, PlayHiveModel obj) {
    writer.writeInt(obj.subjectId);
    writer.writeList(obj.items);
    writer.writeList(obj.sources);
  }
}
