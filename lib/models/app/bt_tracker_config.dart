const recommendedTrackerSources = [
  'https://cdn.jsdelivr.net/gh/ngosang/trackerslist@master/'
      'trackers_best_ip.txt',
  'https://cdn.jsdelivr.net/gh/ngosang/trackerslist@master/'
      'trackers_best.txt',
];

class BtTrackerConfig {
  const BtTrackerConfig({
    this.sources = recommendedTrackerSources,
    this.manualTrackers = const [],
    this.autoUpdate = true,
    this.lastUpdateAttemptAt,
    this.lastUpdateSuccessAt,
    this.lastUpdateError,
    this.sourceEtags = const {},
    this.sourceLastModified = const {},
  });

  factory BtTrackerConfig.fromJson(Map<String, dynamic> json) {
    var config = BtTrackerConfig(
      sources: _readStrings(
        json,
        'sources',
        fallback: recommendedTrackerSources,
      ),
      manualTrackers: _readStrings(json, 'manualTrackers'),
      autoUpdate: json['autoUpdate'] as bool? ?? true,
      lastUpdateAttemptAt: _readTime(json['lastUpdateAttemptAt']),
      lastUpdateSuccessAt: _readTime(json['lastUpdateSuccessAt']),
      lastUpdateError: json['lastUpdateError'] as String?,
      sourceEtags: _readStringMap(json, 'sourceEtags'),
      sourceLastModified: _readStringMap(json, 'sourceLastModified'),
    );
    config.validate();
    return config;
  }

  final List<String> sources;
  final List<String> manualTrackers;
  final bool autoUpdate;
  final DateTime? lastUpdateAttemptAt;
  final DateTime? lastUpdateSuccessAt;
  final String? lastUpdateError;
  final Map<String, String> sourceEtags;
  final Map<String, String> sourceLastModified;

  Map<String, dynamic> toJson() {
    return {
      'sources': sources,
      'manualTrackers': manualTrackers,
      'autoUpdate': autoUpdate,
      'lastUpdateAttemptAt': lastUpdateAttemptAt?.toUtc().toIso8601String(),
      'lastUpdateSuccessAt': lastUpdateSuccessAt?.toUtc().toIso8601String(),
      'lastUpdateError': lastUpdateError,
      'sourceEtags': sourceEtags,
      'sourceLastModified': sourceLastModified,
    };
  }

  BtTrackerConfig copyWith({
    List<String>? sources,
    List<String>? manualTrackers,
    bool? autoUpdate,
    DateTime? lastUpdateAttemptAt,
    DateTime? lastUpdateSuccessAt,
    Object? lastUpdateError = _notProvided,
    Map<String, String>? sourceEtags,
    Map<String, String>? sourceLastModified,
  }) {
    return BtTrackerConfig(
      sources: sources ?? this.sources,
      manualTrackers: manualTrackers ?? this.manualTrackers,
      autoUpdate: autoUpdate ?? this.autoUpdate,
      lastUpdateAttemptAt: lastUpdateAttemptAt ?? this.lastUpdateAttemptAt,
      lastUpdateSuccessAt: lastUpdateSuccessAt ?? this.lastUpdateSuccessAt,
      lastUpdateError: identical(lastUpdateError, _notProvided)
          ? this.lastUpdateError
          : lastUpdateError as String?,
      sourceEtags: sourceEtags ?? this.sourceEtags,
      sourceLastModified: sourceLastModified ?? this.sourceLastModified,
    );
  }

  void validate() {
    if (sources.length > 8) {
      throw const FormatException('Tracker sources cannot exceed 8 entries');
    }
    for (var source in sources) {
      var uri = Uri.tryParse(source);
      if (uri == null ||
          !{'http', 'https'}.contains(uri.scheme.toLowerCase()) ||
          uri.host.isEmpty ||
          uri.userInfo.isNotEmpty ||
          uri.hasFragment) {
        throw const FormatException('Tracker source URL is invalid');
      }
    }
    if (manualTrackers.length > 512) {
      throw const FormatException('Manual Trackers cannot exceed 512 entries');
    }
  }

  static List<String> _readStrings(
    Map<String, dynamic> json,
    String key, {
    List<String> fallback = const [],
  }) {
    var value = json[key];
    if (value == null) return List<String>.of(fallback);
    if (value is! List) {
      throw FormatException('$key must be an array');
    }
    return value
        .map((item) {
          if (item is! String) {
            throw FormatException('$key must contain strings');
          }
          return item;
        })
        .toList(growable: false);
  }

  static DateTime? _readTime(Object? value) {
    if (value == null) return null;
    if (value is! String) throw const FormatException('time must be a string');
    var time = DateTime.tryParse(value);
    if (time == null) throw const FormatException('time is invalid');
    return time.toLocal();
  }

  static Map<String, String> _readStringMap(
    Map<String, dynamic> json,
    String key,
  ) {
    var value = json[key];
    if (value == null) return const {};
    if (value is! Map) throw FormatException('$key must be an object');
    return value.map((mapKey, mapValue) {
      if (mapKey is! String || mapValue is! String) {
        throw FormatException('$key must contain string values');
      }
      return MapEntry(mapKey, mapValue);
    });
  }

  static const _notProvided = Object();
}
