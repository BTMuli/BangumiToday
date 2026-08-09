// Dart imports:
import 'dart:async';
import 'dart:io';

// Package imports:
import 'package:path/path.dart' as path;

// Project imports:
import '../windows_job_object.dart';
import 'protocol.dart';

abstract interface class BtEngineProcess {
  Stream<List<int>> get stdout;
  Stream<List<int>> get stderr;
  IOSink get stdin;
  Future<int> get exitCode;
  bool kill();
}

class IoBtEngineProcess implements BtEngineProcess {
  IoBtEngineProcess(this._process, {WindowsJobObject? jobObject})
    : _jobObject = jobObject {
    unawaited(
      _process.exitCode.then(
        (_) => _releaseJobObject(),
        onError: (Object _, StackTrace _) => _releaseJobObject(),
      ),
    );
  }

  final Process _process;
  WindowsJobObject? _jobObject;

  @override
  Stream<List<int>> get stdout => _process.stdout;

  @override
  Stream<List<int>> get stderr => _process.stderr;

  @override
  IOSink get stdin => _process.stdin;

  @override
  Future<int> get exitCode => _process.exitCode;

  @override
  bool kill() => _process.kill();

  void _releaseJobObject() {
    _jobObject?.close();
    _jobObject = null;
  }
}

typedef BtEngineProcessStarter =
    Future<BtEngineProcess> Function(String executable, List<String> arguments);

/// Starts the sidecar process and supervises it under a Windows Job Object.
Future<BtEngineProcess> startBtEngineProcess(
  String executable,
  List<String> arguments,
) async {
  var process = await Process.start(
    executable,
    arguments,
    workingDirectory: path.dirname(executable),
    mode: ProcessStartMode.normal,
  );
  try {
    var jobObject = Platform.isWindows
        ? WindowsJobObject.attach(process.pid)
        : null;
    return IoBtEngineProcess(process, jobObject: jobObject);
  } catch (error) {
    process.kill();
    try {
      await process.exitCode.timeout(const Duration(seconds: 2));
    } on TimeoutException {
      // The process has already received a termination request. Preserve the
      // Job Object error because supervision is mandatory on Windows.
    }
    throw BtEngineClientException(
      'failed to supervise download engine process: $error',
    );
  }
}
