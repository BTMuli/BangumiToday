// Project imports:
import '../../core/constants/app_constants.dart';

enum BangumiMirrorType {
  site,
  api,
  image;

  String get label => switch (this) {
    site => '站点镜像',
    api => 'API 镜像',
    image => '图片镜像',
  };

  String get configKey => switch (this) {
    site => 'bangumiSiteUrl',
    api => 'bangumiUrl',
    image => 'bangumiImageUrl',
  };

  String get defaultUrl => switch (this) {
    site => BTAppConstants.defaultBangumiSiteBaseUrl,
    api => BTAppConstants.defaultBangumiApiBaseUrl,
    image => BTAppConstants.defaultBangumiImageBaseUrl,
  };

  List<BangumiMirror> get builtIns => switch (this) {
    site => const [
      BangumiMirror._('bgm.tv（官方）', BTAppConstants.officialBangumiSiteBaseUrl),
      BangumiMirror._('bangumi.vip', BTAppConstants.bangumiVipSiteBaseUrl),
      BangumiMirror._('AniBT', BTAppConstants.anibtBangumiSiteBaseUrl),
    ],
    api => const [
      BangumiMirror._('bgm.tv（官方）', BTAppConstants.officialBangumiApiBaseUrl),
      BangumiMirror._('bangumi.vip', BTAppConstants.bangumiVipApiBaseUrl),
      BangumiMirror._('AniBT', BTAppConstants.anibtBangumiApiBaseUrl),
    ],
    image => const [
      BangumiMirror._('bgm.tv（官方）', BTAppConstants.officialBangumiImageBaseUrl),
      BangumiMirror._('bangumi.vip', BTAppConstants.bangumiVipImageBaseUrl),
      BangumiMirror._('AniBT', BTAppConstants.anibtBangumiImageBaseUrl),
    ],
  };

  String normalize(String? url) => switch (this) {
    site => BTAppConstants.normalizeBangumiSiteUrl(url),
    api => BTAppConstants.normalizeBangumiApiUrl(url),
    image => BTAppConstants.normalizeBangumiImageUrl(url),
  };

  bool isBuiltIn(String url) =>
      builtIns.any((mirror) => mirror.url == normalize(url));
}

class BangumiMirror {
  const BangumiMirror._(this.name, this.url);

  factory BangumiMirror({required String name, required String url}) {
    var label = name.trim();
    if (label.isEmpty) throw const FormatException('请输入镜像名称');
    var origin = BTAppConstants.normalizeBangumiMirrorOrigin(url);
    if (origin == null) {
      throw const FormatException('请输入 HTTP/HTTPS 地址，仅含域名和可选端口');
    }
    return BangumiMirror._(label, origin);
  }

  factory BangumiMirror.fromJson(Map<String, dynamic> json) =>
      BangumiMirror(name: json['name'] as String, url: json['url'] as String);

  final String name;
  final String url;

  Map<String, dynamic> toJson() => {'name': name, 'url': url};

  @override
  bool operator ==(Object other) =>
      other is BangumiMirror && name == other.name && url == other.url;

  @override
  int get hashCode => Object.hash(name, url);
}

/// 自定义选项与历史地址一起保存，改名、改址或删除后仍能改写缓存链接。
class BangumiMirrorCatalog {
  const BangumiMirrorCatalog() : this._(const {}, const {});

  const BangumiMirrorCatalog._(this._entries, this._previousUrls);

  /// [json] 也可能来自跨引擎的方法通道，StandardMessageCodec 将所有映射
  /// 解码为 `Map<Object?, Object?>`，嵌套映射需要逐层复制为字符串键映射。
  factory BangumiMirrorCatalog.fromJson(Map<Object?, Object?> json) {
    var catalog = const BangumiMirrorCatalog();
    var previous = <BangumiMirrorType, List<String>>{};
    var savedPrevious = Map<String, Object?>.from(
      json['previousUrls'] as Map? ?? const {},
    );
    for (var type in BangumiMirrorType.values) {
      for (var item in json[type.name] as List? ?? const []) {
        catalog = catalog.save(
          type,
          BangumiMirror.fromJson(Map<String, dynamic>.from(item as Map)),
        );
      }
      previous[type] = List.unmodifiable({
        ...catalog.knownUrls(type),
        for (var value in savedPrevious[type.name] as List? ?? const [])
          ?BTAppConstants.normalizeBangumiMirrorOrigin(value as String),
      });
    }
    return BangumiMirrorCatalog._(catalog._entries, Map.unmodifiable(previous));
  }

  final Map<BangumiMirrorType, List<BangumiMirror>> _entries;
  final Map<BangumiMirrorType, List<String>> _previousUrls;

  List<BangumiMirror> entries(BangumiMirrorType type) =>
      _entries[type] ?? const [];

  List<String> knownUrls(BangumiMirrorType type) => [
    ...?_previousUrls[type],
    ...entries(type).map((mirror) => mirror.url),
  ];

  BangumiMirrorCatalog save(
    BangumiMirrorType type,
    BangumiMirror mirror, {
    String? originalUrl,
  }) {
    if (type.isBuiltIn(mirror.url) ||
        (originalUrl != null && type.isBuiltIn(originalUrl))) {
      throw const FormatException('内置镜像不能新增或修改');
    }
    var current = entries(type);
    if (originalUrl != null &&
        !current.any((entry) => entry.url == originalUrl)) {
      throw const FormatException('镜像已被删除，请重新选择');
    }
    if (current.any(
      (entry) =>
          entry.url != originalUrl &&
          (entry.url == mirror.url ||
              entry.name.toLowerCase() == mirror.name.toLowerCase()),
    )) {
      throw const FormatException('该类别已有同名或相同地址的镜像');
    }
    return _replace(type, [
      for (var entry in current)
        if (entry.url == originalUrl) mirror else entry,
      if (originalUrl == null) mirror,
    ]);
  }

  BangumiMirrorCatalog remove(BangumiMirrorType type, String url) {
    if (type.isBuiltIn(url)) throw const FormatException('内置镜像不能删除');
    if (!entries(type).any((entry) => entry.url == url)) {
      throw const FormatException('镜像已被删除，请重新选择');
    }
    return _replace(type, [
      for (var entry in entries(type))
        if (entry.url != url) entry,
    ]);
  }

  BangumiMirrorCatalog _replace(
    BangumiMirrorType type,
    List<BangumiMirror> entries,
  ) => BangumiMirrorCatalog._(
    Map.unmodifiable({
      ..._entries,
      type: List<BangumiMirror>.unmodifiable(entries),
    }),
    Map.unmodifiable({
      ..._previousUrls,
      type: List<String>.unmodifiable(knownUrls(type).toSet()),
    }),
  );

  Map<String, dynamic> toJson() => {
    for (var type in BangumiMirrorType.values)
      type.name: entries(type).map((entry) => entry.toJson()).toList(),
    'previousUrls': {
      for (var type in BangumiMirrorType.values)
        type.name: knownUrls(type).toSet().toList(),
    },
  };

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! BangumiMirrorCatalog) return false;
    for (var type in BangumiMirrorType.values) {
      var current = entries(type);
      var compared = other.entries(type);
      if (current.length != compared.length) return false;
      for (var i = 0; i < current.length; i++) {
        if (current[i] != compared[i]) return false;
      }
      var urls = knownUrls(type).toSet();
      var otherUrls = other.knownUrls(type).toSet();
      if (urls.length != otherUrls.length || !urls.containsAll(otherUrls)) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll([
    for (var type in BangumiMirrorType.values)
      Object.hash(
        Object.hashAll(entries(type)),
        Object.hashAllUnordered(knownUrls(type).toSet()),
      ),
  ]);
}
