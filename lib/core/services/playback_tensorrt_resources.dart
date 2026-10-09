// Dart imports:
import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;

// Package imports:
import 'package:crypto/crypto.dart';
import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as path;

// Project imports:
import '../../models/playback/playback_janai_status.dart';
import 'file_service.dart';
import 'playback_tensorrt_gpu.dart';
import 'playback_tensorrt_precompile.dart';

/// Optional components are pinned by the application, never by a remote feed.
/// Settings detect a compatible GPU before an explicitly requested download.
/// The Player also checks its actual D3D11 device. A file lock coordinates
/// installation across independent Flutter engines and application processes.
///
/// Components live in the application's own data directory rather than
/// `%LOCALAPPDATA%`. An MSIX package redirects the latter into its per-package
/// `LocalCache`, so a path built from the environment variable resolves to a
/// physical location that the extractor's own process does not see, and the
/// archive appears missing at extraction time.
class PlaybackTensorRtResources {
  PlaybackTensorRtResources({
    required this.onChanged,
    String? bundleDirectory,
    String? dataDirectory,
  }) : bundleDirectory =
           bundleDirectory ?? path.dirname(Platform.resolvedExecutable),
       _dataDirectory = dataDirectory;

  /// Root of the TensorRT components; resolved before the first use.
  String? _dataDirectory;

  /// The component root, resolved by [initialize].
  String get dataDirectory =>
      _dataDirectory ?? (throw StateError('TensorRT 组件目录尚未初始化'));

  static const version = '11.3.0.99';
  static const manifestSha256 =
      '4257c34ded46a338f95109b448ad7932cb57b0b9966f04186dc135ef173ffc47';
  final void Function() onChanged;
  final String bundleDirectory;
  int get _sm => gpu?.sm ?? 0;
  String get runtimeDirectory => path.join(dataDirectory, version, 'sm$_sm');
  String get engineDirectory => path.join(dataDirectory, 'engines');
  PlaybackJanaiStatus? native;
  PlaybackTensorRtGpu? gpu;
  String stage = 'idle';
  String message = '';
  int received = 0;
  int total = 0;
  int installedBytes = 0;
  bool get busy => _flight != null;
  bool get canDownload => gpu?.supported == true;
  bool get installed => _installed;
  bool get preparingEngines => stage == 'precompiling';
  int completedEngines = 0;
  List<String> get precompileLines => _precompileLines;
  bool get ready => installed && canDownload && !busy && !checking;
  bool get canEnable =>
      ready &&
      (native == null ||
          native!.gpuVendor == 0 ||
          (native!.gpuVendor == 0x10de &&
              native!.gpuSm == _sm &&
              native!.gpuDriver >= 13040));
  bool get checking => _checking;
  String get configurationHint => checking
      ? '正在检查 TensorRT 配置'
      : gpu == null
      ? '请先在应用设置中配置 TensorRT'
      : !canDownload
      ? gpu!.requirement
      : busy
      ? 'TensorRT 正在准备组件和引擎'
      : !installed
      ? '请先在应用设置中安装并校验 TensorRT 组件'
      : !canEnable
      ? '当前播放显卡不支持 TensorRT'
      : 'AI 实时超分 · 常用尺寸复用引擎，其他尺寸首次编译';
  String get configurationLabel =>
      busy || stage == 'failed' || stage == 'cancelled'
      ? message
      : checking
      ? '正在检查显卡和已安装组件'
      : !canDownload
      ? gpu?.requirement ?? '等待检测显卡'
      : installed
      ? '配置完成，可在播放器中启用 AI 超分'
      : '尚未安装 TensorRT 组件';
  bool get visible =>
      !_noticeDismissed &&
      (native?.preparing == true ||
          native?.phase == 'resources_missing' ||
          native?.phase == 'failed' ||
          _buildCompleted);
  bool get buildCompleted => _buildCompleted;
  double? get progress => stage == 'downloading' && total > 0
      ? (received / total).clamp(0.0, 1.0)
      : null;
  String get label => _buildCompleted
      ? native?.active == true
            ? 'TensorRT 模型编译完成，AI 超分已启用'
            : 'TensorRT 模型编译完成，等待视频帧'
      : native?.reason.isNotEmpty == true
      ? native!.reason
      : native?.label ?? '';
  List<String> get lines => _buildLines;
  List<String> get installationLines => List.unmodifiable(_installationLines);
  List<String> _buildLines = const [];
  String _buildLog = '';
  bool _buildCompleted = false;
  bool _noticeDismissed = false;
  Timer? _buildNoticeTimer;
  final List<String> _installationLines = [];
  List<String> _precompileLines = const [];
  final _precompiler = PlaybackTensorRtPrecompile();
  bool _installed = false;
  String? _checkedSnapshot;
  Future<void>? _refreshFlight;
  bool _checking = false;
  Timer? _refreshTimer;
  HttpClient? _client;
  Process? _extractor;
  Future<bool>? _flight;
  bool _cancelled = false;
  bool _disposed = false;
  int _lastProgress = 0;

  Future<void> initialize() async {
    if (_disposed || !Platform.isWindows) return;
    await _resolveDataDirectory();
    if (_disposed) return;
    _refreshTimer ??= Timer.periodic(
      const Duration(seconds: 3),
      (_) => unawaited(refresh()),
    );
    await refresh(detectGpu: gpu == null);
  }

  /// Resolves the component root through the application's data directory.
  /// Resolved once; later calls keep the first result.
  Future<void> _resolveDataDirectory() async {
    if (_dataDirectory != null || !Platform.isWindows) return;
    _dataDirectory = await playbackTensorRtDirectory();
  }

  /// Installation changes are shared with already-open playback windows.
  /// Hash only when the marker or file metadata changes, not on every poll.
  Future<void> refresh({bool detectGpu = false, bool force = false}) {
    if (_disposed || busy || !Platform.isWindows) return Future.value();
    if (_refreshFlight != null) return _refreshFlight!;
    var previousInstalled = _installed;
    var previousGpu = gpu;
    var explicitCheck = detectGpu || force;
    _checking = explicitCheck;
    var operation = _refresh(detectGpu: detectGpu, force: force);
    _refreshFlight = operation;
    if (_checking) onChanged();
    return operation.whenComplete(() {
      _refreshFlight = null;
      _checking = false;
      if (!_disposed &&
          (explicitCheck ||
              previousInstalled != _installed ||
              previousGpu != gpu)) {
        onChanged();
      }
    });
  }

  Future<void> _refresh({required bool detectGpu, required bool force}) async {
    try {
      if (detectGpu || gpu == null) gpu = await PlaybackTensorRtGpu.detect();
      if (_disposed) return;
      if (!canDownload) {
        _installed = false;
        _checkedSnapshot = null;
        total = installedBytes = 0;
        return;
      }
      var manifest = await _manifest();
      var files = _selectedAssets(manifest, 'files');
      total = _selectedAssets(
        manifest,
        'archives',
      ).fold(0, (sum, item) => sum + (item['bytes'] as int));
      installedBytes = files.fold(
        0,
        (sum, item) => sum + (item['bytes'] as int),
      );
      var marker = File(path.join(runtimeDirectory, 'installed.json'));
      if (!await marker.exists()) {
        _installed = false;
        _checkedSnapshot = null;
        return;
      }
      var snapshot = StringBuffer(runtimeDirectory);
      for (var name in ['installed.json', ...files.map((f) => f['name'])]) {
        var stat = await File(
          path.join(runtimeDirectory, name as String),
        ).stat();
        snapshot.write('$name:${stat.type}:${stat.size}:${stat.modified};');
      }
      var key = snapshot.toString();
      if (!force && key == _checkedSnapshot) return;
      _installed = false;
      _checkedSnapshot = key;
      if (await marker.length() > 4096) {
        throw const FormatException('TensorRT 安装记录过大');
      }
      var record =
          jsonDecode(await marker.readAsString()) as Map<String, dynamic>;
      if (record['schemaVersion'] != 1 ||
          record['trtVersion'] != version ||
          record['sm'] != _sm ||
          record['manifestSha256'] != manifestSha256) {
        throw const FormatException('TensorRT 配置版本已变化，请重新安装组件');
      }
      await _verifySet(runtimeDirectory, files);
      if (_disposed) return;
      _installed = true;
      _update('ready', 'TensorRT 组件校验通过');
    } catch (error) {
      if (_disposed) return;
      _installed = false;
      _update('failed', 'TensorRT 配置检查失败：$error');
    }
  }

  void beginBuild() {
    _buildLog = '';
    _buildLines = const [];
    observe(null);
  }

  void observe(PlaybackJanaiStatus? status) {
    if (_disposed) return;
    var previous = native;
    if (status == null || status.preparing) {
      _buildNoticeTimer?.cancel();
      _buildCompleted = false;
      _noticeDismissed = false;
    } else if (status.phase == 'failed' ||
        status.phase == 'resources_missing') {
      if (status.phase != previous?.phase) {
        _buildCompleted = false;
        _holdBuildNotice(const Duration(seconds: 12));
      }
    } else if (previous?.preparing == true &&
        (status.phase == 'configured' || status.active)) {
      _buildCompleted = true;
      _holdBuildNotice(const Duration(seconds: 8));
    }
    if (status?.buildLog.isNotEmpty == true) {
      if (_buildLog != status!.buildLog) _buildLines = const [];
      _buildLog = status.buildLog;
    }
    if (status?.buildLines.isNotEmpty == true) {
      _buildLines = status!.buildLines;
    }
    if (status?.phase == 'resources_missing') {
      _installed = false;
      _checkedSnapshot = null;
    }
    native = status;
    onChanged();
  }

  void _holdBuildNotice(Duration duration) {
    _buildNoticeTimer?.cancel();
    _noticeDismissed = false;
    _buildNoticeTimer = Timer(duration, dismissBuildNotice);
  }

  void dismissBuildNotice() {
    if (_disposed) return;
    _buildNoticeTimer?.cancel();
    _buildCompleted = false;
    _noticeDismissed = true;
    onChanged();
  }

  void _update(String next, String text) {
    if (stage == next && message == text) return;
    var time = DateTime.now().toIso8601String().substring(11, 19);
    _installationLines.add('[$time] $text');
    if (_installationLines.length > 200) _installationLines.removeAt(0);
    stage = next;
    message = text;
    if (!_disposed) onChanged();
  }

  void _checkCancelled() {
    if (_cancelled || _disposed) throw const _Cancelled();
  }

  void cancel() {
    _cancelled = true;
    _client?.close(force: true);
    _extractor?.kill();
    _precompiler.cancel();
  }

  void dispose() {
    _disposed = true;
    _refreshTimer?.cancel();
    _buildNoticeTimer?.cancel();
    cancel();
  }

  Future<bool> install() {
    if (_flight != null) return _flight!;
    _cancelled = false;
    _flight = _installAndPrepare();
    return _flight!.whenComplete(() {
      _flight = null;
      if (!_disposed) onChanged();
    });
  }

  Future<bool> _installAndPrepare() async {
    if (!await _install()) return false;
    try {
      _checkCancelled();
      completedEngines = 0;
      _precompileLines = const [];
      _update('precompiling', '准备 720p、1080p 的四个 AI 引擎');
      _checkCancelled();
      await _precompiler.run(
        bundle: bundleDirectory,
        runtime: runtimeDirectory,
        cache: engineDirectory,
        sm: _sm,
        onProgress: (progress) {
          completedEngines = progress.completed;
          _precompileLines = progress.lines;
          _update('precompiling', progress.label);
        },
      );
      _checkCancelled();
      _update('ready', '配置完成，720p、1080p 的四个 AI 引擎已就绪');
      return true;
    } catch (error) {
      if (_cancelled || _disposed || error is _Cancelled) {
        _update('cancelled', '引擎准备已取消，重试时复用已完成的引擎');
      } else {
        _update('failed', 'TensorRT 引擎准备失败：$error');
      }
      return false;
    }
  }

  Future<Map<String, dynamic>> _manifest() async {
    var file = File(path.join(bundleDirectory, 'tensorrt-components.json'));
    if (await file.length() > 65536) {
      throw const FormatException('TensorRT 组件清单过大');
    }
    var bytes = await file.readAsBytes();
    if (bytes.length > 65536 ||
        sha256
                .convert(
                  utf8.encode(utf8.decode(bytes).replaceAll('\r\n', '\n')),
                )
                .toString() !=
            manifestSha256) {
      throw const FormatException('TensorRT 组件清单校验失败，请更新应用');
    }
    var manifest = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    if (manifest['schemaVersion'] != 1 ||
        manifest['bridgeAbi'] != 8 ||
        manifest['trtVersion'] != version ||
        !(manifest['supportedSm'] as List).contains(_sm)) {
      throw const FormatException('TensorRT 组件版本不匹配');
    }
    return manifest;
  }

  List<Map<String, dynamic>> _selectedAssets(
    Map<String, dynamic> manifest,
    String key,
  ) => (manifest[key] as List)
      .cast<Map<String, dynamic>>()
      .where((item) => {'common', 'crt', 'sm$_sm'}.contains(item['group']))
      .toList();

  Future<bool> _install() async {
    Directory? staging;
    Directory? replaced;
    Directory? interrupted;
    RandomAccessFile? installLock;
    bool locked = false;
    var extracted = false;
    try {
      await _refreshFlight;
      gpu ??= await PlaybackTensorRtGpu.detect();
      _checkCancelled();
      if (!canDownload) throw StateError(gpu!.requirement);
      _installed = false;
      _checkedSnapshot = null;
      _update('checking', '检查 TensorRT 组件');
      var manifest = await _manifest();
      var files = _selectedAssets(manifest, 'files');
      var archives = _selectedAssets(manifest, 'archives');
      total = archives.fold(0, (sum, item) => sum + (item['bytes'] as int));
      installedBytes = files.fold(
        0,
        (sum, item) => sum + (item['bytes'] as int),
      );
      await Directory(
        path.join(dataDirectory, version),
      ).create(recursive: true);
      installLock = await File(
        path.join(dataDirectory, '$version.install.lock'),
      ).open(mode: FileMode.append);
      var deadline = DateTime.now().add(const Duration(minutes: 15));
      while (!locked) {
        _checkCancelled();
        try {
          await installLock.lock(FileLock.exclusive);
          locked = true;
        } on FileSystemException {
          if (DateTime.now().isAfter(deadline)) throw StateError('等待其他窗口安装超时');
          _update('waiting', '另一个窗口正在安装组件，等待完成');
          await Future<void>.delayed(const Duration(milliseconds: 500));
        }
      }
      _checkCancelled();
      if (await Directory(runtimeDirectory).exists()) {
        try {
          await _verifySet(runtimeDirectory, files);
          _checkCancelled();
          await _writeInstalledRecord(runtimeDirectory);
          _installed = true;
          _update('ready', 'TensorRT 组件已就绪');
          return true;
        } on FormatException {
          // Never modify a loaded DLL in place. Move the broken set aside and
          // restore it if this transaction fails before publishing a new set.
          if (await FileSystemEntity.type(
                runtimeDirectory,
                followLinks: false,
              ) !=
              FileSystemEntityType.directory) {
            throw const FormatException('组件目录是链接，无法修复');
          }
          var transaction = DateTime.now().microsecondsSinceEpoch;
          replaced = await Directory(
            runtimeDirectory,
          ).rename('$runtimeDirectory.invalid-$pid-$transaction');
        }
      }
      var requiredBytes =
          total +
          files.fold<int>(0, (sum, item) => sum + (item['bytes'] as int)) +
          64 * 1024 * 1024;
      // A half-extracted set is kept for diagnostics only until the next
      // explicit attempt, so failures stay inspectable without leaking space.
      for (var leftover in Directory(dataDirectory).listSync()) {
        if (leftover is! Directory) continue;
        var name = path.basename(leftover.path);
        var partial = name.startsWith(
          '${path.basename(runtimeDirectory)}.staging-$pid-',
        );
        var invalid = name.startsWith(
          '${path.basename(runtimeDirectory)}.invalid-',
        );
        if (!partial && !invalid) continue;
        var bytes = _directoryBytes(leftover);
        try {
          await leftover.delete(recursive: true);
          _update(
            'checking',
            '清理上次的解压残留 · ${(bytes / 1048576).toStringAsFixed(1)} MB',
          );
        } on FileSystemException {
          /* A loaded set remains until process exit. */
        }
      }
      if (_freeBytes(dataDirectory) < requiredBytes) {
        throw StateError(
          '安装需要约 ${(requiredBytes / 1073741824).toStringAsFixed(1)} GB 可用空间',
        );
      }
      var downloads = Directory(path.join(dataDirectory, 'downloads'));
      await downloads.create(recursive: true);
      received = 0;
      var completed = 0;
      var downloaded = <File>[];
      for (var archive in archives) {
        _checkCancelled();
        var file = File(
          path.join(downloads.path, '${archive['sha256']}.7z.part'),
        );
        await _download(archive, file, completed);
        _update('verifying', '校验下载的 ${archive['group']} 组件');
        if (await _digest(file.path) != archive['sha256']) {
          await file.delete();
          throw const FormatException('组件 SHA-256 不匹配，请重试下载');
        }
        _checkCancelled();
        completed += archive['bytes'] as int;
        downloaded.add(file);
      }
      var transaction = DateTime.now().microsecondsSinceEpoch;
      staging = Directory('$runtimeDirectory.staging-$pid-$transaction');
      await staging.create();
      for (var index = 0; index < archives.length; index++) {
        _checkCancelled();
        _update('extracting', '正在解压 ${archives[index]['group']} 组件');
        // The archive was verified above; a failed extraction re-checks it,
        // because security software can remove a verified .7z.part between
        // the digest check and the extraction.
        var group = archives[index];
        var archive = downloaded[index];
        for (var attempt = 1; ; attempt++) {
          try {
            await _extractArchive(group, archive, staging, files);
            extracted = true;
            break;
          } catch (error) {
            _checkCancelled();
            await _requireArchive(archive, group['sha256'] as String);
            if (attempt >= 2) {
              throw StateError(
                '$error · ${_extractContext(staging.path, files)}',
              );
            }
            _update('extracting', '解压中断，正在重试（$error）');
          }
        }
      }
      // The upstream common archive carries a DirectML license as well; the
      // optional runtime installs only TensorRT/CUDA's locked file set.
      var unrelatedLicense = File(
        path.join(staging.path, 'DirectML_LICENSE.txt'),
      );
      if (await unrelatedLicense.exists()) await unrelatedLicense.delete();
      for (var file in files.where((item) => item['group'] == 'crt')) {
        _checkCancelled();
        await File(
          path.join(
            bundleDirectory,
            'playback_inference',
            file['name'] as String,
          ),
        ).copy(path.join(staging.path, file['name'] as String));
      }
      _update('verifying', '正在校验安装文件');
      await _verifySet(staging.path, files);
      _checkCancelled();
      await _writeInstalledRecord(staging.path);
      await staging.rename(runtimeDirectory);
      staging = null;
      if (replaced != null) {
        try {
          await replaced.delete(recursive: true);
        } on FileSystemException {
          /* A loaded set remains until process exit. */
        }
        replaced = null;
      }
      // Only complete archives are removed. Cancellation keeps verified partial
      // downloads for a Range retry and never publishes the staging directory.
      for (var file in downloaded) {
        try {
          await file.delete();
          var etag = File('${file.path}.etag');
          if (await etag.exists()) await etag.delete();
        } on FileSystemException {
          /* Cache cleanup does not invalidate install. */
        }
      }
      _installed = true;
      _update('ready', '配置完成，可在播放器中启用 AI 超分');
      return true;
    } catch (error) {
      if (_cancelled || _disposed || error is _Cancelled) {
        _update('cancelled', '下载已取消，重试时继续下载');
      } else {
        _update('failed', 'TensorRT 安装失败：$error');
        // Keep a failed extraction set for inspection; the next attempt clears
        // it. A failed download keeps verified archives for a Range retry.
        if (extracted && staging != null) {
          interrupted = staging;
          staging = null;
        }
      }
      return false;
    } finally {
      _client?.close(force: true);
      _client = null;
      if (staging != null) {
        // Delete only this transaction's known sibling of the final runtime.
        if (path.dirname(staging.path) == path.dirname(runtimeDirectory) &&
            path
                .basename(staging.path)
                .startsWith(
                  '${path.basename(runtimeDirectory)}.staging-$pid-',
                )) {
          try {
            await staging.delete(recursive: true);
          } on FileSystemException {
            /* Retry later. */
          }
        }
      }
      if (interrupted != null) {
        try {
          await interrupted.rename('${interrupted.path}-interrupted-$pid');
        } on FileSystemException {
          /* The directory is already inspectable in place. */
        }
      }
      if (replaced != null && !await Directory(runtimeDirectory).exists()) {
        try {
          await replaced.rename(runtimeDirectory);
        } on FileSystemException catch (error) {
          _update('failed', '安装失败且无法恢复原目录：$error');
        }
      }
      if (installLock != null) {
        try {
          if (locked) await installLock.unlock();
        } finally {
          await installLock.close();
        }
      }
    }
  }

  Future<void> _writeInstalledRecord(String directory) =>
      File(path.join(directory, 'installed.json')).writeAsString(
        jsonEncode({
          'schemaVersion': 1,
          'trtVersion': version,
          'sm': _sm,
          'manifestSha256': manifestSha256,
        }),
      );

  Future<void> _download(
    Map<String, dynamic> archive,
    File file,
    int completed,
  ) async {
    var expected = archive['bytes'] as int;
    Object? failure;
    for (var attempt = 0; attempt < 3; attempt++) {
      _checkCancelled();
      _client?.close(force: true);
      var client = _client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 30);
      client.autoUncompress = false;
      RandomAccessFile? output;
      try {
        var offset = await file.exists() ? await file.length() : 0;
        if (offset > expected) {
          await file.delete();
          offset = 0;
        }
        received = completed + offset;
        _update('downloading', '正在下载 TensorRT 组件 · ${archive['group']}');
        if (offset == expected) return;
        var etagFile = File('${file.path}.etag');
        var etag = await etagFile.exists()
            ? await etagFile.readAsString()
            : null;
        var uri = Uri.parse(archive['url'] as String);
        HttpClientResponse? response;
        for (var redirect = 0; redirect <= 5; redirect++) {
          _checkCancelled();
          if (!_allowedUrl(uri)) throw const FormatException('组件下载地址不在白名单');
          var request = await client.getUrl(uri);
          request.followRedirects = false;
          request.headers.set(HttpHeaders.acceptEncodingHeader, 'identity');
          if (offset > 0) {
            request.headers.set(HttpHeaders.rangeHeader, 'bytes=$offset-');
            if (etag != null) {
              request.headers.set(HttpHeaders.ifRangeHeader, etag);
            }
          }
          response = await request.close().timeout(const Duration(seconds: 30));
          if (![301, 302, 303, 307, 308].contains(response.statusCode)) break;
          var location = response.headers.value(HttpHeaders.locationHeader);
          await response.drain<void>();
          if (location == null || redirect == 5) {
            throw const HttpException('组件重定向过多');
          }
          uri = uri.resolve(location);
        }
        if (response == null || ![200, 206].contains(response.statusCode)) {
          throw HttpException('组件 HTTP ${response?.statusCode}');
        }
        if (response.statusCode == 206) {
          var range = RegExp(r'^bytes (\d+)-(\d+)/(\d+)$').firstMatch(
            response.headers.value(HttpHeaders.contentRangeHeader) ?? '',
          );
          if (range == null ||
              int.parse(range[1]!) != offset ||
              int.parse(range[2]!) != expected - 1 ||
              int.parse(range[3]!) != expected) {
            throw const HttpException('续传范围不匹配');
          }
        } else {
          offset = 0;
        }
        if (response.contentLength != -1 &&
            response.contentLength != expected - offset) {
          throw const HttpException('组件长度不匹配');
        }
        var newEtag = response.headers.value(HttpHeaders.etagHeader);
        if (newEtag != null) {
          await etagFile.writeAsString(newEtag);
        } else if (await etagFile.exists()) {
          await etagFile.delete();
        }
        output = await file.open(
          mode: offset == 0 ? FileMode.write : FileMode.append,
        );
        await for (var chunk in response.timeout(const Duration(seconds: 30))) {
          _checkCancelled();
          offset += chunk.length;
          if (offset > expected) throw const HttpException('组件超过声明长度');
          await output.writeFrom(chunk);
          received = completed + offset;
          var now = DateTime.now().millisecondsSinceEpoch;
          if (now - _lastProgress >= 100) {
            _lastProgress = now;
            if (!_disposed) onChanged();
          }
        }
        if (offset != expected) throw const HttpException('组件下载不完整');
        await output.flush();
        return;
      } catch (error) {
        failure = error;
        _checkCancelled();
        if (attempt < 2) {
          _update('waiting', '连接中断，正在续传组件（${attempt + 1}/2）');
          await Future<void>.delayed(Duration(seconds: attempt + 1));
        }
      } finally {
        await output?.close();
        client.close(force: true);
      }
    }
    throw StateError('下载失败：$failure');
  }

  /// Extracts one verified archive into the staging directory after checking
  /// that it only carries the manifest's locked entry names. A failure keeps
  /// the extractor's stderr, which names the cause.
  Future<void> _extractArchive(
    Map<String, dynamic> archive,
    File file,
    Directory staging,
    List<Map<String, dynamic>> files,
  ) async {
    var names = files
        .where((item) => item['group'] == archive['group'])
        .map((item) => 'animejanai/inference/${item['name']}')
        .toSet();
    if (archive['group'] == 'common') {
      names.add('animejanai/inference/DirectML_LICENSE.txt');
    }
    var listing = await _runTar(['-tf', file.path]);
    var actual = listing
        .split(RegExp(r'[\r\n]+'))
        .where((name) => name.isNotEmpty)
        .toList();
    if (actual.length != names.length ||
        actual.toSet().difference(names).isNotEmpty ||
        actual.toSet().length != actual.length) {
      throw const FormatException('组件归档包含未授权路径');
    }
    await _runTar([
      '-xf',
      file.path,
      '--strip-components=2',
      '-C',
      staging.path,
    ]);
  }

  /// The verified archive must still be readable before another extraction
  /// attempt, because security software removes .part files it distrusts.
  Future<void> _requireArchive(File file, String sha256) async {
    if (await FileSystemEntity.type(file.path, followLinks: false) !=
            FileSystemEntityType.file ||
        await _digest(file.path) != sha256) {
      throw FormatException(
        '组件归档在解压前被删除或改动（${path.basename(file.path)}），'
        '请检查安全软件拦截记录后重试安装',
      );
    }
  }

  /// A failed extractor is reported with its stderr, because the Windows
  /// archive tool explains the cause there.
  Future<String> _runTar(List<String> arguments) async {
    _checkCancelled();
    var system = path.join(Platform.environment['SystemRoot']!, 'System32');
    var process = _extractor = await Process.start(
      path.join(system, 'tar.exe'),
      arguments,
      workingDirectory: system,
      includeParentEnvironment: false,
      environment: {
        'SystemRoot': Platform.environment['SystemRoot']!,
        'PATH': system,
      },
    );
    var output = <int>[];
    var stdout = process.stdout.forEach((bytes) {
      if (output.length + bytes.length > 65536) {
        process.kill();
        return;
      }
      output.addAll(bytes);
    });
    var errors = <int>[];
    var stderr = process.stderr.forEach((bytes) {
      if (errors.length >= 4096) return;
      errors.addAll(bytes);
    });
    try {
      var exit = await process.exitCode.timeout(
        const Duration(minutes: 3),
        onTimeout: () {
          process.kill();
          throw TimeoutException('组件解压超时');
        },
      );
      await stdout;
      await stderr;
      _checkCancelled();
      if (exit != 0) {
        var reason = _tail(utf8.decode(errors, allowMalformed: true));
        throw StateError('组件解压失败（$exit）${reason.isEmpty ? '' : '：$reason'}');
      }
      return utf8.decode(output);
    } finally {
      _extractor = null;
    }
  }

  /// Diagnostics for a field failure: how far extraction got, which file
  /// stopped it, how much space the destination volume has, and the staging
  /// directory left behind for inspection.
  String _extractContext(String directory, List<Map<String, dynamic>> files) {
    var written = 0;
    var anomaly = '';
    for (var file in files) {
      var name = file['name'] as String;
      var expected =
          (file['bytes'] as int) -
          File(path.join(directory, name)).lengthSync();
      if (expected > 0) {
        anomaly = '$name（缺 ${(expected / 1048576).toStringAsFixed(1)} MB）';
        break;
      }
      written++;
    }
    var bytes = _freeBytes(dataDirectory);
    return '已写入 $written/${files.length} 个文件'
        '${anomaly.isEmpty ? '' : '，中断于 $anomaly'}，'
        '目标可用 ${(bytes / 1073741824).toStringAsFixed(1)} GB，'
        '暂存 $directory';
  }

  static String _tail(String text) {
    var lines = text
        .split(RegExp(r'[\r\n]+'))
        .where((line) => line.trim().isNotEmpty)
        .toList();
    if (lines.length <= 3) return lines.join('；');
    return '${lines.take(2).join('；')}；…；${lines.last}';
  }

  static bool _allowedUrl(Uri uri) =>
      uri.scheme == 'https' &&
      uri.port == 443 &&
      uri.userInfo.isEmpty &&
      ['github.com', 'release-assets.githubusercontent.com'].contains(uri.host);
}

class _Cancelled implements Exception {
  const _Cancelled();
}

Future<String> _digest(String file) => Isolate.run(
  () async => (await sha256.bind(File(file).openRead()).first).toString(),
);

Future<void> _verifySet(String directory, List<Map<String, dynamic>> files) =>
    Isolate.run(() async {
      if (await FileSystemEntity.type(directory, followLinks: false) !=
          FileSystemEntityType.directory) {
        throw const FormatException('组件目录不可用');
      }
      for (var file in files) {
        var candidate = File(path.join(directory, file['name'] as String));
        if (await FileSystemEntity.type(candidate.path, followLinks: false) !=
                FileSystemEntityType.file ||
            await candidate.length() != file['bytes'] ||
            (await sha256.bind(candidate.openRead()).first).toString() !=
                file['sha256']) {
          throw FormatException('组件损坏或缺失：${file['name']}');
        }
      }
    });

/// Size of a leftover directory, used to report what a retry reclaimed.
int _directoryBytes(Directory directory) {
  var total = 0;
  try {
    for (var entry in directory.listSync(recursive: true, followLinks: false)) {
      if (entry is File) total += entry.lengthSync();
    }
  } on FileSystemException {
    /* Report what is readable. */
  }
  return total;
}

int _freeBytes(String directory) {
  var function = DynamicLibrary.open('kernel32.dll')
      .lookupFunction<
        Int32 Function(
          Pointer<Utf16>,
          Pointer<Uint64>,
          Pointer<Uint64>,
          Pointer<Uint64>,
        ),
        int Function(
          Pointer<Utf16>,
          Pointer<Uint64>,
          Pointer<Uint64>,
          Pointer<Uint64>,
        )
      >('GetDiskFreeSpaceExW');
  var name = directory.toNativeUtf16();
  var available = calloc<Uint64>();
  try {
    if (function(name, available, nullptr, nullptr) == 0) {
      throw const FileSystemException('无法检查可用磁盘空间');
    }
    return math.max(0, available.value);
  } finally {
    calloc.free(name);
    calloc.free(available);
  }
}
