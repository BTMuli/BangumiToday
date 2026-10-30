const btEngineProtocolVersion = '1.9';
const btEngineMaxProtocolFrameBytes = 1024 * 1024;

T? _requiredNullable<T>(Map<String, dynamic> json, String key) {
  if (!json.containsKey(key)) throw FormatException('缺少协议字段：$key');
  return json[key] as T?;
}

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
      retryable: json['retryable'] as bool,
    );
  }

  final String code;
  final String message;
  final bool retryable;

  String get recoveryHint => switch (code) {
    'DISK_FULL' => '释放保存磁盘空间后重试',
    'SAVE_PATH_NOT_WRITABLE' => '恢复保存目录的写入权限后重试',
    'SAVE_PATH_UNAVAILABLE' => '确认保存目录或磁盘已连接后重试',
    'STORAGE_ERROR' => '检查磁盘、目录权限和文件占用后重试',
    'NETWORK_UNAVAILABLE' || 'HTTP_TRANSFER_ERROR' => '检查网络和代理连接后重试',
    'HTTP_STATUS_ERROR' =>
      retryable ? '等待服务器恢复或解除限流后重试' : '检查下载链接与访问权限；链接失效时重新添加任务',
    'TLS_ERROR' => '检查系统时间、证书和代理配置；修正后重新添加任务',
    'SOURCE_INVALID' ||
    'SOURCE_UNSUPPORTED' ||
    'HTTP_REDIRECT_ERROR' => '检查资源链接或种子文件后重新添加任务',
    'SAVE_PATH_INVALID' => '使用有效的保存路径重新添加任务',
    'DATA_VERIFICATION_FAILED' => '检查磁盘或资源完整性，可尝试重新校验',
    _ => retryable ? '修正错误原因后重试' : '修正资源或配置后重新添加任务',
  };

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
    required this.manual,
    required this.savePath,
    required this.displayName,
    required this.infoHash,
    required this.totalBytes,
    required this.downloadedBytes,
    required this.verifiedBytes,
    required this.uploadedBytes,
    required this.shareRatio,
    required this.seedingSeconds,
    required this.downloadMilliseconds,
    required this.seedRatioLimit,
    required this.seedTimeLimitMinutes,
    required this.seedStopReason,
    required this.pauseReason,
    required this.progress,
    required this.downloadRate,
    required this.uploadRate,
    required this.peers,
    required this.seeds,
    required this.isPrivate,
    required this.lastError,
  });

  factory BtTaskSnapshot.fromJson(Map<String, dynamic> json) {
    var downloadMilliseconds = json['downloadMilliseconds'] as int;
    if (downloadMilliseconds < 0) {
      throw const FormatException('downloadMilliseconds 必须是非负整数');
    }
    return BtTaskSnapshot(
      id: json['id'] as String,
      state: json['state'] as String,
      sourceKind: json['sourceKind'] as String,
      manual: json['manual'] as bool,
      savePath: json['savePath'] as String,
      displayName: json['displayName'] as String? ?? '',
      infoHash: json['infoHash'] as String?,
      totalBytes: (json['totalBytes'] as num?)?.toInt() ?? 0,
      downloadedBytes: (json['downloadedBytes'] as num?)?.toInt() ?? 0,
      verifiedBytes: (json['verifiedBytes'] as num?)?.toInt() ?? 0,
      uploadedBytes: (json['uploadedBytes'] as num?)?.toInt() ?? 0,
      shareRatio: (json['shareRatio'] as num?)?.toDouble() ?? 0,
      seedingSeconds: (json['seedingSeconds'] as num?)?.toInt() ?? 0,
      downloadMilliseconds: downloadMilliseconds,
      seedRatioLimit: (json['seedRatioLimit'] as num?)?.toDouble() ?? 2,
      seedTimeLimitMinutes:
          (json['seedTimeLimitMinutes'] as num?)?.toInt() ?? 60,
      seedStopReason: json['seedStopReason'] as String?,
      pauseReason: json['pauseReason'] as String?,
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
  final bool manual;
  final String savePath;
  final String displayName;
  final String? infoHash;
  final int totalBytes;
  final int downloadedBytes;
  final int verifiedBytes;
  final int uploadedBytes;
  final double shareRatio;
  final int seedingSeconds;

  /// 单任务累计下载耗时；仅在下载状态且下载速度大于 0 时计时。
  final int downloadMilliseconds;
  final double seedRatioLimit;
  final int seedTimeLimitMinutes;
  final String? seedStopReason;
  final String? pauseReason;
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
        manual == other.manual &&
        savePath == other.savePath &&
        displayName == other.displayName &&
        infoHash == other.infoHash &&
        totalBytes == other.totalBytes &&
        downloadedBytes == other.downloadedBytes &&
        verifiedBytes == other.verifiedBytes &&
        uploadedBytes == other.uploadedBytes &&
        shareRatio == other.shareRatio &&
        seedingSeconds == other.seedingSeconds &&
        downloadMilliseconds == other.downloadMilliseconds &&
        seedRatioLimit == other.seedRatioLimit &&
        seedTimeLimitMinutes == other.seedTimeLimitMinutes &&
        seedStopReason == other.seedStopReason &&
        pauseReason == other.pauseReason &&
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
    manual,
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
      downloadMilliseconds,
      seedRatioLimit,
      seedTimeLimitMinutes,
      seedStopReason,
      pauseReason,
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
    required this.userAgent,
    required this.peerId,
    required this.peerIdClient,
    required this.progress,
    required this.downloadRate,
    required this.uploadRate,
    required this.choked,
    required this.interested,
    required this.remoteChoked,
    required this.remoteInterested,
    required this.connectionState,
    required this.seed,
    required this.transport,
    required this.encryption,
    required this.sources,
    required this.trackerUrls,
  });

  factory BtTaskPeerDetail.fromJson(
    Map<String, dynamic> json, {
    required List<String> trackerUrls,
  }) {
    var peerId = json['peerId'] as String;
    if (!RegExp(r'^(?:[0-9a-f]{40})?$').hasMatch(peerId)) {
      throw const FormatException('peerId 必须为空或 20 字节的十六进制编码');
    }
    return BtTaskPeerDetail(
      endpoint: json['endpoint'] as String,
      userAgent: json['userAgent'] as String,
      peerId: peerId,
      peerIdClient: json['peerIdClient'] as String,
      progress: (json['progress'] as num).toDouble().clamp(0, 1),
      downloadRate: (json['downloadRate'] as num).toInt(),
      uploadRate: (json['uploadRate'] as num).toInt(),
      choked: json['choked'] as bool,
      interested: json['interested'] as bool,
      remoteChoked: json['remoteChoked'] as bool,
      remoteInterested: json['remoteInterested'] as bool,
      connectionState: json['connectionState'] as String,
      seed: json['seed'] as bool,
      transport: json['transport'] as String,
      encryption: json['encryption'] as String,
      sources: (json['sources'] as List).cast<String>(),
      trackerUrls: (json['trackerIndices'] as List)
          .map((index) => trackerUrls[index as int])
          .toList(growable: false),
    );
  }

  final String endpoint;

  /// 对端扩展握手的 v 字段；未收到声明时为空，不使用 Peer ID 推断填充。
  final String userAgent;

  /// 20 字节 Peer ID 的 40 位十六进制编码；基础握手未完成时为空。
  final String peerId;

  /// 引擎仅根据 Peer ID 指纹识别的客户端，与握手声明独立。
  final String peerIdClient;
  final bool choked;
  final bool interested;
  final bool remoteChoked;
  final bool remoteInterested;
  final String connectionState;
  final bool seed;
  final String transport;
  final String encryption;
  final List<String> sources;

  /// 最近 30 分钟实际返回过此地址的 Tracker，可包含多个；运行期记录不持久化。
  final List<String> trackerUrls;
  final double progress;
  final int downloadRate;
  final int uploadRate;

  /// 展示用地址：IPv6 的 `[地址]:端口` 会去掉两侧方括号。
  String get endpointLabel => endpoint.replaceAll('[', '').replaceAll(']', '');

  /// 原始 Peer ID 的可复制表示，非打印字节和反斜杠使用转义保留。
  String get peerIdLabel {
    var result = StringBuffer();
    for (var i = 0; i < peerId.length; i += 2) {
      var hex = peerId.substring(i, i + 2);
      var byte = int.parse(hex, radix: 16);
      if (byte == 0x5c) {
        result.write(r'\\');
      } else if (byte >= 0x20 && byte <= 0x7e) {
        result.writeCharCode(byte);
      } else {
        result.write('\\x$hex');
      }
    }
    return result.toString();
  }

  /// 从实际 UA 握手声明拆分的客户端名称，用于 UA 列展示与筛选。
  String get clientName => _splitClient(userAgent).$1;

  /// 客户端版本；客户端字符串不含版本时为空字符串。
  String get clientVersion => _splitClient(userAgent).$2;

  /// 拆分 UA 中以斜杠或空格分隔的名称和版本，原始声明仍完整保留。
  /// 无法拆分时原样展示，不以 Peer ID 指纹补齐。
  static (String, String) _splitClient(String raw) {
    var value = raw.trim();
    if (value.isEmpty) return ('unknown', '');
    var match = RegExp(
      r'^([^/]+?)(?:/|\s+)([0-9]+(?:\.[0-9]+)*'
      r'(?:(?:dev|[abr])[0-9]*|[-+][0-9A-Za-z.+-]+)?'
      r'(?: \(tag [ -~]\))?)$',
    ).firstMatch(value);
    return match == null ? (value, '') : (match[1]!, match[2]!);
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
    this.httpConnections = 0,
    required this.httpRangeSupported,
    required this.httpTransferMode,
    required this.httpResponseStatus,
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
    var peers = parseList(
      'peers',
      (peer) => BtTaskPeerDetail.fromJson(
        peer,
        trackerUrls: List<String>.from(json['trackerUrls'] as List),
      ),
    );
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
      httpConnections: (json['httpConnections'] as num?)?.toInt() ?? 0,
      httpRangeSupported: _requiredNullable<bool>(json, 'httpRangeSupported'),
      httpTransferMode: json['httpTransferMode'] as String,
      httpResponseStatus: _requiredNullable<num>(
        json,
        'httpResponseStatus',
      )?.toInt(),
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
  final int httpConnections;
  final bool? httpRangeSupported;
  final String httpTransferMode;
  final int? httpResponseStatus;
}

class BtTaskTrackerDetail {
  const BtTaskTrackerDetail({
    required this.url,
    required this.tier,
    required this.endpoint,
    required this.protocol,
    required this.state,
    required this.lastError,
    required this.message,
    required this.nextAnnounceSeconds,
    required this.peers,
  });

  factory BtTaskTrackerDetail.fromJson(Map<String, dynamic> json) =>
      BtTaskTrackerDetail(
        url: json['url'] as String,
        tier: (json['tier'] as num).toInt(),
        endpoint: json['endpoint'] as String,
        protocol: json['protocol'] as String,
        state: json['state'] as String,
        lastError: json['lastError'] as String,
        message: json['message'] as String,
        nextAnnounceSeconds: _requiredNullable<num>(
          json,
          'nextAnnounceSeconds',
        )?.toInt(),
        peers: _requiredNullable<num>(json, 'peers')?.toInt(),
      );

  final String url;
  final int tier;
  final String endpoint;
  final String protocol;
  final String state;
  final String lastError;
  final String message;
  final int? nextAnnounceSeconds;
  final int? peers;
}

class BtTaskTrackersResult {
  BtTaskTrackersResult.fromJson(Map<String, dynamic> json)
    : trackers = (json['trackers'] as List)
          .map(
            (value) => BtTaskTrackerDetail.fromJson(
              Map<String, dynamic>.from(value as Map),
            ),
          )
          .toList(growable: false),
      totalTrackers = (json['totalTrackers'] as num).toInt(),
      offset = (json['offset'] as num).toInt(),
      nextOffset = _requiredNullable<num>(json, 'nextOffset')?.toInt();

  final List<BtTaskTrackerDetail> trackers;
  final int totalTrackers;
  final int offset;
  final int? nextOffset;
}

class BtEngineNetworkStatus {
  BtEngineNetworkStatus.fromJson(Map<String, dynamic> json)
    : listening = json['listening'] as bool,
      listenPort = (json['listenPort'] as num).toInt(),
      dhtEnabled = json['dhtEnabled'] as bool,
      dhtRunning = json['dhtRunning'] as bool,
      dhtNodes = _requiredNullable<num>(json, 'dhtNodes')?.toInt(),
      dhtSampled = json['dhtSampled'] as bool,
      lsdEnabled = json['lsdEnabled'] as bool,
      upnpEnabled = json['upnpEnabled'] as bool,
      natPmpEnabled = json['natPmpEnabled'] as bool,
      listeners = (json['listeners'] as List)
          .map(
            (value) => BtEngineListenerStatus.fromJson(
              Map<String, dynamic>.from(value as Map),
            ),
          )
          .toList(growable: false),
      portMappings = (json['portMappings'] as List)
          .map(
            (value) => BtEnginePortMappingStatus.fromJson(
              Map<String, dynamic>.from(value as Map),
            ),
          )
          .toList(growable: false);

  final bool listening;
  final int listenPort;
  final bool dhtEnabled;
  final bool dhtRunning;
  final int? dhtNodes;
  final bool dhtSampled;
  final bool lsdEnabled;
  final bool upnpEnabled;
  final bool natPmpEnabled;
  final List<BtEngineListenerStatus> listeners;
  final List<BtEnginePortMappingStatus> portMappings;
}

class BtEngineListenerStatus {
  BtEngineListenerStatus.fromJson(Map<String, dynamic> json)
    : address = json['address'] as String,
      port = (json['port'] as num).toInt(),
      socketType = json['socketType'] as String,
      state = json['state'] as String,
      error = json['error'] as String;

  final String address;
  final int port;
  final String socketType;
  final String state;
  final String error;
}

class BtEnginePortMappingStatus {
  BtEnginePortMappingStatus.fromJson(Map<String, dynamic> json)
    : address = json['address'] as String,
      transport = json['transport'] as String,
      state = json['state'] as String,
      externalPort = _requiredNullable<num>(json, 'externalPort')?.toInt(),
      error = json['error'] as String;

  final String address;
  final String transport;
  final String state;
  final int? externalPort;
  final String error;
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
    var trackerUrls = List<String>.from(json['trackerUrls'] as List);
    var values = json['peers'];
    var peers = values is List
        ? values
              .whereType<Map>()
              .map(
                (value) => BtTaskPeerDetail.fromJson(
                  Map<String, dynamic>.from(value),
                  trackerUrls: trackerUrls,
                ),
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
