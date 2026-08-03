class BtDownloadConfig {
  const BtDownloadConfig({
    this.engineEnabled = false,
    this.activeDownloads = 4,
    this.downloadRateLimit = 0,
    this.uploadRateLimit = 0,
    this.connectionsLimit = 256,
    this.connectionsPerTask = 64,
    this.metadataTimeoutSeconds = 300,
    this.seedingEnabled = true,
    this.seedRatioLimit = 2,
    this.seedTimeLimitMinutes = 60,
    this.seedingDisclosureAccepted = true,
  });

  const BtDownloadConfig.freshInstall()
    : engineEnabled = false,
      activeDownloads = 4,
      downloadRateLimit = 0,
      uploadRateLimit = 0,
      connectionsLimit = 256,
      connectionsPerTask = 64,
      metadataTimeoutSeconds = 300,
      seedingEnabled = true,
      seedRatioLimit = 2,
      seedTimeLimitMinutes = 60,
      seedingDisclosureAccepted = true;

  factory BtDownloadConfig.fromJson(Map<String, dynamic> json) {
    var config = BtDownloadConfig(
      engineEnabled: json['engineEnabled'] as bool? ?? false,
      activeDownloads: _readInt(json, 'activeDownloads', 4),
      downloadRateLimit: _readInt(json, 'downloadRateLimit', 0),
      uploadRateLimit: _readInt(json, 'uploadRateLimit', 0),
      connectionsLimit: _readInt(json, 'connectionsLimit', 256),
      connectionsPerTask: _readInt(json, 'connectionsPerTask', 64),
      metadataTimeoutSeconds: _readInt(json, 'metadataTimeoutSeconds', 300),
      seedingEnabled: json['seedingEnabled'] as bool? ?? false,
      seedRatioLimit: _readDouble(json, 'seedRatioLimit', 2),
      seedTimeLimitMinutes: _readInt(json, 'seedTimeLimitMinutes', 60),
      seedingDisclosureAccepted:
          json['seedingDisclosureAccepted'] as bool? ?? false,
    );
    config.validate();
    return config;
  }

  /// 下载引擎是否已手动开启。默认关闭；开启后应用启动时会自动运行
  /// bt_download，并自动注册防火墙规则。
  final bool engineEnabled;
  final int activeDownloads;
  final int downloadRateLimit;
  final int uploadRateLimit;
  final int connectionsLimit;
  final int connectionsPerTask;
  final int metadataTimeoutSeconds;
  final bool seedingEnabled;
  final double seedRatioLimit;
  final int seedTimeLimitMinutes;
  final bool seedingDisclosureAccepted;

  int get downloadRateLimitKiB => downloadRateLimit ~/ 1024;
  int get uploadRateLimitKiB => uploadRateLimit ~/ 1024;

  Map<String, dynamic> toJson() {
    return {
      'engineEnabled': engineEnabled,
      'activeDownloads': activeDownloads,
      'downloadRateLimit': downloadRateLimit,
      'uploadRateLimit': uploadRateLimit,
      'connectionsLimit': connectionsLimit,
      'connectionsPerTask': connectionsPerTask,
      'metadataTimeoutSeconds': metadataTimeoutSeconds,
      'seedingEnabled': seedingEnabled,
      'seedRatioLimit': seedRatioLimit,
      'seedTimeLimitMinutes': seedTimeLimitMinutes,
      'seedingDisclosureAccepted': seedingDisclosureAccepted,
    };
  }

  Map<String, dynamic> toEngineJson({
    List<String> additionalTrackers = const [],
  }) {
    var json = toJson()
      ..remove('engineEnabled')
      ..remove('seedingDisclosureAccepted')
      ..['seedingEnabled'] = seedingEnabled && seedingDisclosureAccepted
      ..['additionalTrackers'] = List<String>.of(additionalTrackers);
    return json;
  }

  BtDownloadConfig copyWith({
    bool? engineEnabled,
    int? activeDownloads,
    int? downloadRateLimit,
    int? uploadRateLimit,
    int? connectionsLimit,
    int? connectionsPerTask,
    int? metadataTimeoutSeconds,
    bool? seedingEnabled,
    double? seedRatioLimit,
    int? seedTimeLimitMinutes,
    bool? seedingDisclosureAccepted,
  }) {
    return BtDownloadConfig(
      engineEnabled: engineEnabled ?? this.engineEnabled,
      activeDownloads: activeDownloads ?? this.activeDownloads,
      downloadRateLimit: downloadRateLimit ?? this.downloadRateLimit,
      uploadRateLimit: uploadRateLimit ?? this.uploadRateLimit,
      connectionsLimit: connectionsLimit ?? this.connectionsLimit,
      connectionsPerTask: connectionsPerTask ?? this.connectionsPerTask,
      metadataTimeoutSeconds:
          metadataTimeoutSeconds ?? this.metadataTimeoutSeconds,
      seedingEnabled: seedingEnabled ?? this.seedingEnabled,
      seedRatioLimit: seedRatioLimit ?? this.seedRatioLimit,
      seedTimeLimitMinutes: seedTimeLimitMinutes ?? this.seedTimeLimitMinutes,
      seedingDisclosureAccepted:
          seedingDisclosureAccepted ?? this.seedingDisclosureAccepted,
    );
  }

  void validate() {
    if (activeDownloads < 1 || activeDownloads > 64) {
      throw const FormatException('activeDownloads must be between 1 and 64');
    }
    if (connectionsLimit < 1 || connectionsLimit > 10000) {
      throw const FormatException(
        'connectionsLimit must be between 1 and 10000',
      );
    }
    if (connectionsPerTask < 1 || connectionsPerTask > connectionsLimit) {
      throw const FormatException(
        'connectionsPerTask must be between 1 and connectionsLimit',
      );
    }
    const maxRateLimit = 0x7fffffff;
    if (downloadRateLimit < 0 || downloadRateLimit > maxRateLimit) {
      throw const FormatException('downloadRateLimit is invalid');
    }
    if (uploadRateLimit < 0 || uploadRateLimit > maxRateLimit) {
      throw const FormatException('uploadRateLimit is invalid');
    }
    if (metadataTimeoutSeconds < 1 || metadataTimeoutSeconds > 86400) {
      throw const FormatException(
        'metadataTimeoutSeconds must be between 1 and 86400',
      );
    }
    if (!seedRatioLimit.isFinite ||
        (seedRatioLimit != 0 &&
            (seedRatioLimit < 0.1 || seedRatioLimit > 100))) {
      throw const FormatException(
        'seedRatioLimit must be 0 or between 0.1 and 100',
      );
    }
    if (seedTimeLimitMinutes < 0 || seedTimeLimitMinutes > 525600) {
      throw const FormatException(
        'seedTimeLimitMinutes must be between 0 and 525600',
      );
    }
    if (seedingEnabled && seedRatioLimit == 0 && seedTimeLimitMinutes == 0) {
      throw const FormatException(
        'enabled seeding requires at least one stop condition',
      );
    }
  }

  static int _readInt(Map<String, dynamic> json, String key, int fallback) {
    return (json[key] as num?)?.toInt() ?? fallback;
  }

  static double _readDouble(
    Map<String, dynamic> json,
    String key,
    double fallback,
  ) {
    return (json[key] as num?)?.toDouble() ?? fallback;
  }
}
