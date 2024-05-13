// Dart imports:
import 'dart:convert';

// Package imports:
import 'package:hive/hive.dart';

/// BangumiSubject与DandanPlay弹幕关联的Hive模型
class DanmakuHiveModel {
  /// subjectId
  final int subjectId;

  /// animeId
  late int? animeId;

  /// animeTitle
  late String? animeTitle;

  /// episodes，key为集数，value为弹幕id
  late Map<String, dynamic>? episodes;

  /// 构造函数
  DanmakuHiveModel({
    required this.subjectId,
    this.animeId,
    this.animeTitle,
    this.episodes,
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
    var episodes = reader.readString();
    return DanmakuHiveModel(
      subjectId: subjectId,
      animeId: animeId,
      animeTitle: animeTitle,
      episodes: jsonDecode(episodes),
    );
  }

  @override
  void write(BinaryWriter writer, DanmakuHiveModel obj) {
    writer.writeInt(obj.subjectId);
    if (obj.animeId != null) writer.writeInt(obj.animeId!);
    if (obj.animeTitle != null) writer.writeString(obj.animeTitle!);
    if (obj.episodes != null) writer.writeMap(obj.episodes!);
  }
}
