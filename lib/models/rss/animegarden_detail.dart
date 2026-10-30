// Package imports:
import 'package:json_annotation/json_annotation.dart';

// Project imports:
import 'animegarden_resource.dart';

part 'animegarden_detail.g.dart';

@JsonSerializable(explicitToJson: true)
class AnimeGardenDetailResponse {
  const AnimeGardenDetailResponse({
    required this.resource,
    required this.isDeleted,
    this.detail,
    this.duplicatedId,
  });

  final AnimeGardenResource resource;
  final bool? isDeleted;
  final AnimeGardenDetail? detail;
  final int? duplicatedId;

  factory AnimeGardenDetailResponse.fromJson(Map<String, dynamic> json) {
    if (json['status'] != 'OK') {
      throw const FormatException('Anime Garden 详情响应失败');
    }
    var response = _$AnimeGardenDetailResponseFromJson(json);
    if (response.detail != null &&
        response.detail!.id != response.resource.id) {
      throw const FormatException('Anime Garden 详情与资源不匹配');
    }
    return response;
  }

  Map<String, dynamic> toJson() => {
    'status': 'OK',
    ..._$AnimeGardenDetailResponseToJson(this),
  };
}

@JsonSerializable(explicitToJson: true)
class AnimeGardenDetail {
  const AnimeGardenDetail({
    required this.id,
    required this.fetchedAt,
    required this.description,
    required this.files,
    required this.magnets,
    required this.hasMoreFiles,
  });

  final int id;
  final DateTime fetchedAt;
  final String description;
  final List<AnimeGardenFile> files;
  final List<AnimeGardenMagnet> magnets;
  final bool hasMoreFiles;

  factory AnimeGardenDetail.fromJson(Map<String, dynamic> json) =>
      _$AnimeGardenDetailFromJson(json);
  Map<String, dynamic> toJson() => _$AnimeGardenDetailToJson(this);
}

@JsonSerializable()
class AnimeGardenFile {
  const AnimeGardenFile({required this.name, required this.size});

  final String name;

  /// File sizes are upstream display text, not byte counts.
  final String size;

  factory AnimeGardenFile.fromJson(Map<String, dynamic> json) =>
      _$AnimeGardenFileFromJson(json);
  Map<String, dynamic> toJson() => _$AnimeGardenFileToJson(this);
}

@JsonSerializable()
class AnimeGardenMagnet {
  const AnimeGardenMagnet({required this.name, required this.url});

  final String name;
  final String url;

  factory AnimeGardenMagnet.fromJson(Map<String, dynamic> json) =>
      _$AnimeGardenMagnetFromJson(json);
  Map<String, dynamic> toJson() => _$AnimeGardenMagnetToJson(this);
}
