class BtDownloadConfig {
  const BtDownloadConfig({
    this.activeDownloads = 2,
    this.downloadRateLimit = 0,
    this.uploadRateLimit = 1024 * 1024,
    this.connectionsLimit = 200,
    this.connectionsPerTask = 80,
    this.metadataTimeoutSeconds = 300,
  });

  factory BtDownloadConfig.fromJson(Map<String, dynamic> json) {
    var config = BtDownloadConfig(
      activeDownloads: _readInt(json, 'activeDownloads', 2),
      downloadRateLimit: _readInt(json, 'downloadRateLimit', 0),
      uploadRateLimit: _readInt(json, 'uploadRateLimit', 1024 * 1024),
      connectionsLimit: _readInt(json, 'connectionsLimit', 200),
      connectionsPerTask: _readInt(json, 'connectionsPerTask', 80),
      metadataTimeoutSeconds: _readInt(json, 'metadataTimeoutSeconds', 300),
    );
    config.validate();
    return config;
  }

  final int activeDownloads;
  final int downloadRateLimit;
  final int uploadRateLimit;
  final int connectionsLimit;
  final int connectionsPerTask;
  final int metadataTimeoutSeconds;

  int get downloadRateLimitKiB => downloadRateLimit ~/ 1024;
  int get uploadRateLimitKiB => uploadRateLimit ~/ 1024;

  Map<String, dynamic> toJson() {
    return {
      'activeDownloads': activeDownloads,
      'downloadRateLimit': downloadRateLimit,
      'uploadRateLimit': uploadRateLimit,
      'connectionsLimit': connectionsLimit,
      'connectionsPerTask': connectionsPerTask,
      'metadataTimeoutSeconds': metadataTimeoutSeconds,
    };
  }

  BtDownloadConfig copyWith({
    int? activeDownloads,
    int? downloadRateLimit,
    int? uploadRateLimit,
    int? connectionsLimit,
    int? connectionsPerTask,
    int? metadataTimeoutSeconds,
  }) {
    return BtDownloadConfig(
      activeDownloads: activeDownloads ?? this.activeDownloads,
      downloadRateLimit: downloadRateLimit ?? this.downloadRateLimit,
      uploadRateLimit: uploadRateLimit ?? this.uploadRateLimit,
      connectionsLimit: connectionsLimit ?? this.connectionsLimit,
      connectionsPerTask: connectionsPerTask ?? this.connectionsPerTask,
      metadataTimeoutSeconds:
          metadataTimeoutSeconds ?? this.metadataTimeoutSeconds,
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
  }

  static int _readInt(Map<String, dynamic> json, String key, int fallback) {
    return (json[key] as num?)?.toInt() ?? fallback;
  }
}
