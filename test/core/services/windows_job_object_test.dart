import 'dart:io';

import 'package:bangumi_today/core/services/windows_job_object.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'closing a Job Object terminates its assigned process',
    () async {
      var process = await Process.start('powershell', [
        '-NoLogo',
        '-NoProfile',
        '-NonInteractive',
        '-Command',
        'Start-Sleep -Seconds 30',
      ]);
      WindowsJobObject? jobObject;
      var stopwatch = Stopwatch()..start();
      try {
        jobObject = WindowsJobObject.attach(process.pid);
        jobObject.close();
        jobObject = null;

        await process.exitCode.timeout(const Duration(seconds: 5));
        expect(stopwatch.elapsed, lessThan(const Duration(seconds: 5)));
      } finally {
        jobObject?.close();
        process.kill();
      }
    },
    skip: !Platform.isWindows,
  );
}
