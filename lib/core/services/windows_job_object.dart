// Dart imports:
import 'dart:ffi';
import 'dart:io';

// Package imports:
import 'package:ffi/ffi.dart';

const _processTerminate = 0x0001;
const _processSetQuota = 0x0100;
const _jobObjectExtendedLimitInformation = 9;
const _jobObjectLimitKillOnJobClose = 0x00002000;

final _kernel32 = DynamicLibrary.open('kernel32.dll');

final _createJobObject = _kernel32
    .lookupFunction<
      Pointer<Void> Function(Pointer<Void>, Pointer<Utf16>),
      Pointer<Void> Function(Pointer<Void>, Pointer<Utf16>)
    >('CreateJobObjectW');
final _setInformationJobObject = _kernel32
    .lookupFunction<
      Int32 Function(Pointer<Void>, Int32, Pointer<Void>, Uint32),
      int Function(Pointer<Void>, int, Pointer<Void>, int)
    >('SetInformationJobObject');
final _openProcess = _kernel32
    .lookupFunction<
      Pointer<Void> Function(Uint32, Int32, Uint32),
      Pointer<Void> Function(int, int, int)
    >('OpenProcess');
final _assignProcessToJobObject = _kernel32
    .lookupFunction<
      Int32 Function(Pointer<Void>, Pointer<Void>),
      int Function(Pointer<Void>, Pointer<Void>)
    >('AssignProcessToJobObject');
final _closeHandle = _kernel32
    .lookupFunction<Int32 Function(Pointer<Void>), int Function(Pointer<Void>)>(
      'CloseHandle',
    );
final _getLastError = _kernel32
    .lookupFunction<Uint32 Function(), int Function()>('GetLastError');

final class _JobObjectBasicLimitInformation extends Struct {
  @Int64()
  external int perProcessUserTimeLimit;

  @Int64()
  external int perJobUserTimeLimit;

  @Uint32()
  external int limitFlags;

  @IntPtr()
  external int minimumWorkingSetSize;

  @IntPtr()
  external int maximumWorkingSetSize;

  @Uint32()
  external int activeProcessLimit;

  @IntPtr()
  external int affinity;

  @Uint32()
  external int priorityClass;

  @Uint32()
  external int schedulingClass;
}

final class _IoCounters extends Struct {
  @Uint64()
  external int readOperationCount;

  @Uint64()
  external int writeOperationCount;

  @Uint64()
  external int otherOperationCount;

  @Uint64()
  external int readTransferCount;

  @Uint64()
  external int writeTransferCount;

  @Uint64()
  external int otherTransferCount;
}

final class _JobObjectExtendedLimitInformation extends Struct {
  external _JobObjectBasicLimitInformation basicLimitInformation;
  external _IoCounters ioInfo;

  @IntPtr()
  external int processMemoryLimit;

  @IntPtr()
  external int jobMemoryLimit;

  @IntPtr()
  external int peakProcessMemoryUsed;

  @IntPtr()
  external int peakJobMemoryUsed;
}

/// Keeps a Windows Job Object alive for a child process.
///
/// Closing the lease terminates any process still assigned to the job. Windows
/// also closes the handle automatically if the owning application crashes.
final class WindowsJobObject {
  WindowsJobObject._(this._handle);

  Pointer<Void>? _handle;

  static WindowsJobObject attach(int processId) {
    if (!Platform.isWindows) {
      throw UnsupportedError('Windows Job Objects require Windows');
    }

    var jobHandle = _createJobObject(nullptr, nullptr);
    if (jobHandle == nullptr) {
      throw _windowsError('failed to create download engine Job Object');
    }

    try {
      using((arena) {
        var limits = arena<_JobObjectExtendedLimitInformation>();
        limits.ref.basicLimitInformation.limitFlags =
            _jobObjectLimitKillOnJobClose;
        if (_setInformationJobObject(
              jobHandle,
              _jobObjectExtendedLimitInformation,
              limits.cast(),
              sizeOf<_JobObjectExtendedLimitInformation>(),
            ) ==
            0) {
          throw _windowsError('failed to configure download engine Job Object');
        }
      });

      var processHandle = _openProcess(
        _processTerminate | _processSetQuota,
        0,
        processId,
      );
      if (processHandle == nullptr) {
        throw _windowsError('failed to open download engine process');
      }
      try {
        if (_assignProcessToJobObject(jobHandle, processHandle) == 0) {
          throw _windowsError('failed to assign download engine Job Object');
        }
      } finally {
        _closeHandle(processHandle);
      }

      return WindowsJobObject._(jobHandle);
    } catch (_) {
      _closeHandle(jobHandle);
      rethrow;
    }
  }

  void close() {
    var handle = _handle;
    if (handle == null) return;
    _handle = null;
    _closeHandle(handle);
  }
}

OSError _windowsError(String message) => OSError(message, _getLastError());
