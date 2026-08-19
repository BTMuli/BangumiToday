// Dart imports:
import 'dart:ffi';
import 'dart:io';

// Package imports:
import 'package:ffi/ffi.dart';

// Project imports:
import '../../tools/log_tool.dart';
import '../constants/app_constants.dart';

typedef WindowsProcessRunner =
    Future<ProcessResult> Function(String executable, List<String> arguments);

const _assocStrProgId = 20;
const _assocFNoTruncate = 0x00000020;
const _assocFIsProtocol = 0x00001000;
const _shcneAssocChanged = 0x08000000;
// SHCNF_FLUSH 会阻塞到 Explorer 等窗口处理完通知，托盘退出时会卡住主窗体。
const _shcnfFlushNoWait = 0x2000;
const _backupKey = r'HKCU\Software\BangumiToday\DevProtocolHijack';
const _delegateExecuteName = 'DelegateExecute';

/// 把当前可执行文件注册为 `bangumitoday://` 协议处理程序。
Future<void> registerWindowsAppProtocol() {
  return WindowsAppProtocol.instance.register();
}

/// 退出 unpackaged 进程时，把商店版 AppX 协议处理还原回去。
Future<void> restoreWindowsAppProtocol() {
  return WindowsAppProtocol.instance.restore();
}

/// 商店版通过 AppX ProgID 的 `DelegateExecute` 接管协议，HKCU Classes
/// 里的 `command` 会被忽略。unpackaged 进程要改写该 ProgID，退出时再还原。
class WindowsAppProtocol {
  WindowsAppProtocol({
    WindowsProcessRunner? runProcess,
    String? Function()? executable,
    String? Function(String scheme)? protocolProgId,
    void Function()? notifyAssocChanged,
    bool? isWindows,
  }) : _runProcess = runProcess ?? Process.run,
       _executable = executable ?? _resolvedExecutable,
       _protocolProgId = protocolProgId ?? _queryProtocolProgId,
       _notifyAssocChanged = notifyAssocChanged ?? _notifyAssocChangedNative,
       _isWindows = isWindows ?? Platform.isWindows;

  static final WindowsAppProtocol instance = WindowsAppProtocol();

  final WindowsProcessRunner _runProcess;
  final String? Function() _executable;
  final String? Function(String scheme) _protocolProgId;
  final void Function() _notifyAssocChanged;
  final bool _isWindows;

  Future<void> register() async {
    if (!_isWindows) return;
    var exe = _executable();
    if (exe == null || exe.isEmpty) return;
    if (exe.contains(r'\WindowsApps\')) return;

    var scheme = BTAppConstants.urlScheme;
    var command = '"$exe" "%1"';
    var prefix = 'HKCU\\Software\\Classes\\$scheme';
    try {
      await _regAdd(prefix, value: 'URL:BangumiToday');
      await _regAdd(prefix, name: 'URL Protocol', value: '');
      await _regAdd('$prefix\\shell\\open\\command', value: command);

      var progId = _protocolProgId(scheme);
      if (progId != null && progId.toLowerCase().startsWith('appx')) {
        await _takeOverAppX(progId, command);
      }
      _notifyAssocChanged();
      BTLogTool.info('已注册 $scheme:// -> $exe');
    } catch (error) {
      BTLogTool.warn('注册 $scheme:// 协议失败：$error');
    }
  }

  Future<void> restore() async {
    if (!_isWindows) return;
    try {
      var progId = await _regQuery(_backupKey, 'ProgId');
      var delegate = await _regQuery(_backupKey, _delegateExecuteName);
      if (progId == null || progId.isEmpty) return;

      var commandKey = _commandKey(progId);
      await _regDelete(commandKey, defaultValue: true);
      if (delegate != null && delegate.isNotEmpty) {
        await _regAdd(commandKey, name: _delegateExecuteName, value: delegate);
      }
      await _regDelete(_backupKey);
      _notifyAssocChanged();
      BTLogTool.info('已还原商店版协议处理 $progId');
    } catch (error) {
      BTLogTool.warn('还原 bangumitoday:// 协议失败：$error');
    }
  }

  Future<void> _takeOverAppX(String progId, String command) async {
    var commandKey = _commandKey(progId);
    var backedUp = await _regQuery(_backupKey, _delegateExecuteName);
    if (backedUp == null) {
      var current = await _regQuery(commandKey, _delegateExecuteName);
      await _regAdd(_backupKey, name: 'ProgId', value: progId);
      await _regAdd(
        _backupKey,
        name: _delegateExecuteName,
        value: current ?? '',
      );
    } else {
      await _regAdd(_backupKey, name: 'ProgId', value: progId);
    }
    await _regAdd(commandKey, value: command);
    await _regDelete(commandKey, name: _delegateExecuteName);
    BTLogTool.info('已接管商店版协议 $progId');
  }

  String _commandKey(String progId) {
    return 'HKCU\\Software\\Classes\\$progId\\Shell\\open\\command';
  }

  Future<void> _regAdd(
    String key, {
    String? name,
    required String value,
  }) async {
    var args = <String>['add', key];
    if (name != null) {
      args.addAll(['/v', name]);
    } else {
      args.add('/ve');
    }
    args.addAll(['/t', 'REG_SZ', '/d', value, '/f']);
    var result = await _runProcess('reg', args);
    if (result.exitCode != 0) {
      var stderr = result.stderr.toString().trim();
      var detail = stderr.isEmpty ? 'reg exit ${result.exitCode}' : stderr;
      throw StateError(detail);
    }
  }

  Future<String?> _regQuery(String key, String name) async {
    var result = await _runProcess('reg', ['query', key, '/v', name]);
    if (result.exitCode != 0) return null;
    return _readRegSz(result.stdout.toString(), name);
  }

  Future<void> _regDelete(
    String key, {
    String? name,
    bool defaultValue = false,
  }) async {
    var args = <String>['delete', key];
    if (defaultValue) {
      args.addAll(['/ve', '/f']);
    } else if (name != null) {
      args.addAll(['/v', name, '/f']);
    } else {
      args.add('/f');
    }
    await _runProcess('reg', args);
  }
}

String? _resolvedExecutable() => Platform.resolvedExecutable;

String? _readRegSz(String stdout, String name) {
  for (var line in stdout.split('\n')) {
    var trimmed = line.trim();
    if (!trimmed.startsWith(name)) continue;
    var marker = 'REG_SZ';
    var index = trimmed.indexOf(marker);
    if (index < 0) return null;
    return trimmed.substring(index + marker.length).trim();
  }
  return null;
}

String? _queryProtocolProgId(String scheme) {
  if (!Platform.isWindows) return null;
  try {
    return using((Arena arena) {
      var flags = _assocFNoTruncate | _assocFIsProtocol;
      var schemePtr = scheme.toNativeUtf16(allocator: arena);
      var size = arena<Uint32>()..value = 1024;
      var buf = arena<Uint16>(1024);
      var shlwapi = DynamicLibrary.open('shlwapi.dll');
      var assoc = shlwapi
          .lookupFunction<
            Uint32 Function(
              Uint32,
              Uint32,
              Pointer<Utf16>,
              Pointer<Utf16>,
              Pointer<Utf16>,
              Pointer<Uint32>,
            ),
            int Function(
              int,
              int,
              Pointer<Utf16>,
              Pointer<Utf16>,
              Pointer<Utf16>,
              Pointer<Uint32>,
            )
          >('AssocQueryStringW');
      var hr = assoc(
        flags,
        _assocStrProgId,
        schemePtr,
        nullptr,
        buf.cast(),
        size,
      );
      if (hr != 0) return null;
      var value = buf.cast<Utf16>().toDartString();
      if (value.isEmpty) return null;
      return value;
    });
  } catch (_) {
    return null;
  }
}

void _notifyAssocChangedNative() {
  if (!Platform.isWindows) return;
  try {
    var shell32 = DynamicLibrary.open('shell32.dll');
    var notify = shell32
        .lookupFunction<
          Void Function(Int32, Uint32, Pointer<Void>, Pointer<Void>),
          void Function(int, int, Pointer<Void>, Pointer<Void>)
        >('SHChangeNotify');
    notify(_shcneAssocChanged, _shcnfFlushNoWait, nullptr, nullptr);
  } catch (_) {
    // Association cache refresh is best-effort.
  }
}
