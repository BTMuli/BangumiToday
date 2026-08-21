const btEngineProtocolVersion = '1.2';
const btEngineMaxProtocolFrameBytes = 1024 * 1024;

enum BtEngineClientState { stopped, starting, ready, stopping, failed }

class BtTaskError {
  const BtTaskError({
    required this.code,
    required this.message,
    required this.retryable,
  });

  factory BtTaskError.fromJson(Map<String, dynamic> json) {
    return BtTaskError(
      code: json['code'] as String,
      message: json['message'] as String,
      retryable: json['retryable'] as bool? ?? false,
    );
  }

  final String code;
  final String message;
  final bool retryable;

  @override
  bool operator ==(Object other) {
    return other is BtTaskError &&
        code == other.code &&
        message == other.message &&
        retryable == other.retryable;
  }

  @override
  int get hashCode => Object.hash(code, message, retryable);
}

class BtTaskSnapshot {
  const BtTaskSnapshot({
    required this.id,
    required this.state,
    required this.sourceKind,
    required this.savePath,
    required this.displayName,
    required this.infoHash,
    required this.totalBytes,
    required this.downloadedBytes,
    required this.verifiedBytes,
    required this.uploadedBytes,
    required this.shareRatio,
    required this.seedingSeconds,
    required this.seedRatioLimit,
    required this.seedTimeLimitMinutes,
    required this.seedStopReason,
    required this.progress,
    required this.downloadRate,
    required this.uploadRate,
    required this.peers,
    required this.seeds,
    required this.isPrivate,
    required this.lastError,
  });

  factory BtTaskSnapshot.fromJson(Map<String, dynamic> json) {
    return BtTaskSnapshot(
      id: json['id'] as String,
      state: json['state'] as String,
      sourceKind: json['sourceKind'] as String,
      savePath: json['savePath'] as String,
      displayName: json['displayName'] as String? ?? '',
      infoHash: json['infoHash'] as String?,
      totalBytes: (json['totalBytes'] as num?)?.toInt() ?? 0,
      downloadedBytes: (json['downloadedBytes'] as num?)?.toInt() ?? 0,
      verifiedBytes: (json['verifiedBytes'] as num?)?.toInt() ?? 0,
      uploadedBytes: (json['uploadedBytes'] as num?)?.toInt() ?? 0,
      shareRatio: (json['shareRatio'] as num?)?.toDouble() ?? 0,
      seedingSeconds: (json['seedingSeconds'] as num?)?.toInt() ?? 0,
      seedRatioLimit: (json['seedRatioLimit'] as num?)?.toDouble() ?? 2,
      seedTimeLimitMinutes:
          (json['seedTimeLimitMinutes'] as num?)?.toInt() ?? 60,
      seedStopReason: json['seedStopReason'] as String?,
      progress: (json['progress'] as num?)?.toDouble() ?? 0,
      downloadRate: (json['downloadRate'] as num?)?.toInt() ?? 0,
      uploadRate: (json['uploadRate'] as num?)?.toInt() ?? 0,
      peers: (json['peers'] as num?)?.toInt() ?? 0,
      seeds: (json['seeds'] as num?)?.toInt() ?? 0,
      isPrivate: json['private'] as bool? ?? false,
      lastError: json['lastError'] is Map
          ? BtTaskError.fromJson(
              Map<String, dynamic>.from(json['lastError'] as Map),
            )
          : null,
    );
  }

  final String id;
  final String state;
  final String sourceKind;
  final String savePath;
  final String displayName;
  final String? infoHash;
  final int totalBytes;
  final int downloadedBytes;
  final int verifiedBytes;
  final int uploadedBytes;
  final double shareRatio;
  final int seedingSeconds;
  final double seedRatioLimit;
  final int seedTimeLimitMinutes;
  final String? seedStopReason;
  final double progress;
  final int downloadRate;
  final int uploadRate;
  final int peers;
  final int seeds;
  final bool isPrivate;
  final BtTaskError? lastError;

  /// Info hash in a clean, display-friendly form.
  ///
  /// The engine may report libtorrent's [v1,v2] hybrid representation;
  /// strips the wrapper and prefers the v1 hash when present, falling back
  /// to the v2 hash for v2-only torrents.
  String? get displayInfoHash {
    var value = infoHash;
    if (value == null || !value.startsWith('[') || !value.endsWith(']')) {
      return value;
    }
    var parts = value.substring(1, value.length - 1).split(',');
    if (parts.length != 2) return value;
    if (RegExp(r'[^0]').hasMatch(parts[0])) return parts[0];
    if (RegExp(r'[^0]').hasMatch(parts[1])) return parts[1];
    return value;
  }

  @override
  bool operator ==(Object other) {
    return other is BtTaskSnapshot &&
        id == other.id &&
        state == other.state &&
        sourceKind == other.sourceKind &&
        savePath == other.savePath &&
        displayName == other.displayName &&
        infoHash == other.infoHash &&
        totalBytes == other.totalBytes &&
        downloadedBytes == other.downloadedBytes &&
        verifiedBytes == other.verifiedBytes &&
        uploadedBytes == other.uploadedBytes &&
        shareRatio == other.shareRatio &&
        seedingSeconds == other.seedingSeconds &&
        seedRatioLimit == other.seedRatioLimit &&
        seedTimeLimitMinutes == other.seedTimeLimitMinutes &&
        seedStopReason == other.seedStopReason &&
        progress == other.progress &&
        downloadRate == other.downloadRate &&
        uploadRate == other.uploadRate &&
        peers == other.peers &&
        seeds == other.seeds &&
        isPrivate == other.isPrivate &&
        lastError == other.lastError;
  }

  @override
  int get hashCode => Object.hash(
    id,
    state,
    sourceKind,
    savePath,
    displayName,
    infoHash,
    totalBytes,
    downloadedBytes,
    verifiedBytes,
    uploadedBytes,
    Object.hash(
      shareRatio,
      seedingSeconds,
      seedRatioLimit,
      seedTimeLimitMinutes,
      seedStopReason,
      progress,
      downloadRate,
      uploadRate,
      peers,
      seeds,
      isPrivate,
      lastError,
    ),
  );
}

class BtTaskFileDetail {
  const BtTaskFileDetail({
    required this.path,
    required this.size,
    required this.completedBytes,
    this.priority = 4,
    this.paddingFile = false,
  });

  factory BtTaskFileDetail.fromJson(Map<String, dynamic> json) {
    return BtTaskFileDetail(
      path: json['path'] as String? ?? '',
      size: (json['size'] as num?)?.toInt() ?? 0,
      completedBytes: (json['completedBytes'] as num?)?.toInt() ?? 0,
      priority: (json['priority'] as num?)?.toInt() ?? 4,
      paddingFile: json['isPadding'] as bool,
    );
  }

  final String path;
  final int size;
  final int completedBytes;
  final int priority;
  final bool paddingFile;

  double get progress => size <= 0 ? 0 : (completedBytes / size).clamp(0, 1);

  bool get isSkipped => priority <= 0;

  /// libtorrent 的对齐文件，不会写入下载目录，也不应在文件列表中展示。
  bool get isPadding => paddingFile;
}

class BtTaskPeerDetail {
  const BtTaskPeerDetail({
    required this.endpoint,
    required this.client,
    required this.progress,
    required this.downloadRate,
    required this.uploadRate,
  });

  factory BtTaskPeerDetail.fromJson(Map<String, dynamic> json) {
    return BtTaskPeerDetail(
      endpoint: json['endpoint'] as String? ?? '',
      client: json['client'] as String? ?? 'unknown',
      progress: ((json['progress'] as num?)?.toDouble() ?? 0).clamp(0, 1),
      downloadRate: (json['downloadRate'] as num?)?.toInt() ?? 0,
      uploadRate: (json['uploadRate'] as num?)?.toInt() ?? 0,
    );
  }

  final String endpoint;
  final String client;
  final double progress;
  final int downloadRate;
  final int uploadRate;

  /// 展示用地址：IPv6 的 `[地址]:端口` 会去掉两侧方括号。
  String get endpointLabel => endpoint.replaceAll('[', '').replaceAll(']', '');

  /// 客户端名称，例如 `qBittorrent 4.4.5` 解析为 `qBittorrent`。
  String get clientName => _splitClient(client).$1;

  /// 客户端版本；客户端字符串不含版本时为空字符串。
  String get clientVersion => _splitClient(client).$2;

  /// 按常见 Peer 客户端字符串格式拆分名称与版本：
  /// `名称 版本`、`名称/版本`、`名称 名称/版本`，无法识别时整体作为名称。
  static (String, String) _splitClient(String raw) {
    var value = raw.trim();
    if (value.isEmpty) return ('unknown', '');
    var slash = value.lastIndexOf('/');
    if (slash > 0) {
      var name = value.substring(0, slash).trim();
      var version = value.substring(slash + 1).trim();
      return (name.isEmpty ? 'unknown' : name, version);
    }
    var space = value.lastIndexOf(' ');
    if (space > 0) {
      var version = value.substring(space + 1).trim();
      if (_isVersionToken(version)) {
        return (value.substring(0, space).trim(), version);
      }
    }
    return (value, '');
  }

  static bool _isVersionToken(String token) {
    var value = token;
    if (value.isEmpty) return false;
    if (value[0] == 'v' || value[0] == 'V') value = value.substring(1);
    return value.isNotEmpty && RegExp(r'^[0-9][0-9.]*$').hasMatch(value);
  }
}

class BtTaskDetails {
  const BtTaskDetails({
    required this.task,
    required this.pieceLength,
    required this.pieceCount,
    required this.completedPieces,
    required this.files,
    required this.filesTruncated,
    required this.totalFiles,
    required this.contentFileCount,
    required this.peers,
    required this.peersTruncated,
    required this.totalPeers,
  });

  factory BtTaskDetails.fromJson(Map<String, dynamic> json) {
    List<T> parseList<T>(String key, T Function(Map<String, dynamic>) parse) {
      var values = json[key];
      if (values is! List) return const [];
      return values
          .whereType<Map>()
          .map((value) => parse(Map<String, dynamic>.from(value)))
          .toList(growable: false);
    }

    var files = parseList('files', BtTaskFileDetail.fromJson);
    var peers = parseList('peers', BtTaskPeerDetail.fromJson);
    return BtTaskDetails(
      task: BtTaskSnapshot.fromJson(
        Map<String, dynamic>.from(json['task'] as Map),
      ),
      pieceLength: (json['pieceLength'] as num?)?.toInt() ?? 0,
      pieceCount: (json['pieceCount'] as num?)?.toInt() ?? 0,
      completedPieces: json['completedPieces'] as String? ?? '',
      files: files,
      filesTruncated: json['filesTruncated'] as bool? ?? false,
      totalFiles: (json['totalFiles'] as num?)?.toInt() ?? files.length,
      contentFileCount: (json['contentFiles'] as num).toInt(),
      peers: peers,
      peersTruncated: json['peersTruncated'] as bool? ?? false,
      totalPeers: (json['totalPeers'] as num?)?.toInt() ?? peers.length,
    );
  }

  final BtTaskSnapshot task;
  final int pieceLength;
  final int pieceCount;
  final String completedPieces;
  final List<BtTaskFileDetail> files;
  final bool filesTruncated;
  final int totalFiles;

  /// 不包含 libtorrent padding 文件的真实文件数量。
  final int contentFileCount;
  final List<BtTaskPeerDetail> peers;
  final bool peersTruncated;
  final int totalPeers;
}

/// `task.files` 的响应：按 `offset`/`limit` 窗口返回的文件列表。
class BtTaskFilesResult {
  const BtTaskFilesResult({
    required this.files,
    required this.truncated,
    required this.totalFiles,
    required this.offset,
    required this.totalContentFiles,
    this.nextOffset,
  });

  factory BtTaskFilesResult.fromJson(Map<String, dynamic> json) {
    var values = json['files'];
    var files = values is List
        ? values
              .whereType<Map>()
              .map(
                (value) =>
                    BtTaskFileDetail.fromJson(Map<String, dynamic>.from(value)),
              )
              .toList(growable: false)
        : const <BtTaskFileDetail>[];
    return BtTaskFilesResult(
      files: files,
      truncated: json['filesTruncated'] as bool? ?? false,
      totalFiles: (json['totalFiles'] as num?)?.toInt() ?? files.length,
      offset: (json['offset'] as num?)?.toInt() ?? 0,
      totalContentFiles: (json['contentFiles'] as num).toInt(),
      nextOffset: (json['nextOffset'] as num?)?.toInt(),
    );
  }

  final List<BtTaskFileDetail> files;

  /// 当前窗口之后是否仍有文件（`nextOffset` 指向下一页起点）。
  final bool truncated;
  final int totalFiles;
  final int offset;
  final int? nextOffset;

  /// 引擎报告的不包含 padding 文件的总数。
  final int totalContentFiles;

  /// 过滤掉不会落盘的 padding 文件后的数量。
  int get contentFileCount => totalContentFiles;
}

/// `task.peers` 的响应：按 `offset`/`limit` 窗口返回的 Peer 列表。
class BtTaskPeersResult {
  const BtTaskPeersResult({
    required this.peers,
    required this.truncated,
    required this.totalPeers,
    required this.offset,
    this.nextOffset,
  });

  factory BtTaskPeersResult.fromJson(Map<String, dynamic> json) {
    var values = json['peers'];
    var peers = values is List
        ? values
              .whereType<Map>()
              .map(
                (value) =>
                    BtTaskPeerDetail.fromJson(Map<String, dynamic>.from(value)),
              )
              .toList(growable: false)
        : const <BtTaskPeerDetail>[];
    return BtTaskPeersResult(
      peers: peers,
      truncated: json['peersTruncated'] as bool? ?? false,
      totalPeers: (json['totalPeers'] as num?)?.toInt() ?? peers.length,
      offset: (json['offset'] as num?)?.toInt() ?? 0,
      nextOffset: (json['nextOffset'] as num?)?.toInt(),
    );
  }

  final List<BtTaskPeerDetail> peers;

  /// 当前窗口之后是否仍有 Peer（`nextOffset` 指向下一页起点）。
  final bool truncated;
  final int totalPeers;
  final int offset;
  final int? nextOffset;
}

class BtEngineEvent {
  const BtEngineEvent({required this.method, required this.params});

  final String method;
  final Map<String, dynamic> params;
}

class BtEngineClientException implements Exception {
  const BtEngineClientException(this.message);

  final String message;

  @override
  String toString() => 'BtEngineClientException: $message';
}

class BtEngineRpcException extends BtEngineClientException {
  const BtEngineRpcException({
    required String message,
    required this.rpcCode,
    required this.code,
    required this.retryable,
    required this.data,
  }) : super(message);

  final int rpcCode;
  final String code;
  final bool retryable;
  final Map<String, dynamic> data;

  @override
  String toString() => 'BtEngineRpcException($code): $message';
}
