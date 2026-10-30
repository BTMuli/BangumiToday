// Package imports:
import 'package:json_annotation/json_annotation.dart';

part 'animegarden_resource.g.dart';

@JsonSerializable(explicitToJson: true)
class AnimeGardenResource {
  const AnimeGardenResource({
    required this.id,
    required this.provider,
    required this.providerId,
    required this.title,
    required this.href,
    required this.type,
    required this.magnet,
    required this.size,
    required this.createdAt,
    required this.fetchedAt,
    required this.publisher,
    this.tracker,
    this.fansub,
    this.subjectId,
    this.metadata,
  });

  final int id;
  final String provider;
  final String providerId;
  final String title;
  final String href;
  final String type;
  final String magnet;
  final int size;
  final DateTime createdAt;
  final DateTime fetchedAt;
  final AnimeGardenParty publisher;
  final String? tracker;
  final AnimeGardenParty? fansub;
  final int? subjectId;
  final Map<String, dynamic>? metadata;

  String get detailUrl => Uri(
    scheme: 'https',
    host: 'animes.garden',
    pathSegments: ['detail', provider, providerId],
  ).toString();

  /// Upstream returns an already encoded query suffix, including its leading &.
  String get downloadUrl => '$magnet${tracker ?? ''}';

  factory AnimeGardenResource.fromJson(Map<String, dynamic> json) =>
      _$AnimeGardenResourceFromJson(json);
  Map<String, dynamic> toJson() => _$AnimeGardenResourceToJson(this);
}

@JsonSerializable()
class AnimeGardenParty {
  const AnimeGardenParty({required this.id, required this.name, this.avatar});

  final int id;
  final String name;
  final String? avatar;

  factory AnimeGardenParty.fromJson(Map<String, dynamic> json) =>
      _$AnimeGardenPartyFromJson(json);
  Map<String, dynamic> toJson() => _$AnimeGardenPartyToJson(this);
}

@JsonSerializable()
class AnimeGardenPagination {
  const AnimeGardenPagination({
    required this.page,
    required this.pageSize,
    required this.complete,
  });

  final int page;
  final int pageSize;
  final bool complete;

  factory AnimeGardenPagination.fromJson(Map<String, dynamic> json) =>
      _$AnimeGardenPaginationFromJson(json);
  Map<String, dynamic> toJson() => _$AnimeGardenPaginationToJson(this);
}

@JsonSerializable(explicitToJson: true)
class AnimeGardenPage {
  const AnimeGardenPage({required this.resources, required this.pagination});

  final List<AnimeGardenResource> resources;
  final AnimeGardenPagination pagination;

  factory AnimeGardenPage.fromJson(Map<String, dynamic> json) {
    if (json['status'] != 'OK') {
      throw const FormatException('Anime Garden 业务响应失败');
    }
    return _$AnimeGardenPageFromJson(json);
  }

  Map<String, dynamic> toJson() => {
    'status': 'OK',
    ..._$AnimeGardenPageToJson(this),
  };
}
