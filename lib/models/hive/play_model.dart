// Package imports:
import 'package:hive/hive.dart';

/// 同条目的播放项
class PlayHiveItem {
  /// 集数
  late String episode;

  /// 播放进度
  late int progress;

  /// 文件路径
  late String file;

  /// 构造
  PlayHiveItem({this.episode = "0", this.progress = 0, this.file = ''});
}

/// 播放项的Hive适配器
class PlayHiveItemAdapter extends TypeAdapter<PlayHiveItem> {
  @override
  final int typeId = 3;

  @override
  PlayHiveItem read(BinaryReader reader) {
    return PlayHiveItem(
      episode: reader.readString(),
      progress: reader.readInt(),
    );
  }

  @override
  void write(BinaryWriter writer, PlayHiveItem obj) {
    writer.writeString(obj.episode);
    writer.writeInt(obj.progress);
  }
}

/// 视频播放的 Hive 模型
class PlayHiveModel {
  /// 对应条目
  final int subjectId;

  /// 条目名称
  late String subjectName;

  /// 切削用的正则，用于匹配文件名
  late String cutRegex;

  /// 子章节
  late List<PlayHiveItem> items;

  /// 播放列表
  late List<String> playList;

  /// 构造
  PlayHiveModel({
    required this.subjectId,
    this.subjectName = '',
    this.cutRegex = '',
    this.items = const [],
    this.playList = const [],
  });
}

/// 播放的 Hive 适配器
class PlayHiveAdapter extends TypeAdapter<PlayHiveModel> {
  @override
  final int typeId = 2;

  @override
  PlayHiveModel read(BinaryReader reader) {
    return PlayHiveModel(
      subjectId: reader.readInt(),
      subjectName: reader.readString(),
      cutRegex: reader.readString(),
      items: reader.readList().cast<PlayHiveItem>(),
      playList: reader.readList().cast<String>(),
    );
  }

  @override
  void write(BinaryWriter writer, PlayHiveModel obj) {
    writer.writeInt(obj.subjectId);
    writer.writeString(obj.subjectName);
    writer.writeString(obj.cutRegex);
    writer.writeList(obj.items);
    writer.writeList(obj.playList);
  }
}
