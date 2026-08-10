// Verification driver for the home (Bangumi-今日放送) page at default and
// maximized window sizes. Captures screenshots and reports PASS/FAIL.
// Usage: dart run test_driver/home_ui_verify.dart <vmServiceUrl> <outDir>

// Dart imports:
import 'dart:io';

// Package imports:
import 'package:flutter_driver/flutter_driver.dart';

const _winHelper = 'D:/Code/App/bangumi_today/scripts/home_win.ps1';

Future<void> main(List<String> args) async {
  var vmUrl = args.isNotEmpty
      ? args[0]
      : Platform.environment['VM_SERVICE_URL'];
  var outDir = args.length > 1 ? args[1] : Directory.current.path;
  var logFile = File('$outDir/home_ui_verify.log');
  if (logFile.existsSync()) logFile.deleteSync();

  void say(String s) {
    var line = '[${DateTime.now().toIso8601String().substring(11, 19)}] $s';
    logFile.writeAsStringSync('$line\n', mode: FileMode.append);
    try {
      stdout.writeln(line);
      stdout.flush();
    } catch (_) {}
  }

  if (vmUrl == null) {
    say('No VM service URL provided.');
    exit(2);
  }

  var driver = await FlutterDriver.connect(
    dartVmServiceUrl: vmUrl,
    timeout: const Duration(seconds: 60),
  );
  say('CONNECTED');
  await driver.setSemantics(true);

  Future<bool> exists(
    SerializableFinder finder, {
    Duration timeout = const Duration(seconds: 4),
  }) async {
    try {
      await driver.waitFor(finder, timeout: timeout);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> shot(String name) async {
    var png = await driver.screenshot().timeout(const Duration(seconds: 30));
    File('$outDir/$name').writeAsBytesSync(png);
    say('SHOT $name (${png.length} bytes)');
  }

  Future<void> win(String action, [int w = 0, int h = 0]) async {
    var args = <String>[
      '-NoProfile',
      '-ExecutionPolicy',
      'Bypass',
      '-File',
      _winHelper,
      action,
    ];
    if (w > 0 && h > 0) args.addAll(['$w', '$h']);
    var res = await Process.run('powershell', args);
    say('WIN $action => ${(res.stdout as String).trim()}');
    await Future<void>.delayed(const Duration(milliseconds: 1200));
  }

  Future<bool> guarded(String label, Future<bool> Function() action) async {
    try {
      var ok = await action().timeout(const Duration(seconds: 90));
      say(ok ? 'PASS $label' : 'FAIL $label');
      return ok;
    } catch (e) {
      say('FAIL $label => $e');
      return false;
    }
  }

  // Wait for the home page (weekday tabs of the calendar TabView).
  await guarded('home page loaded', () async {
    return exists(find.text('星期一'), timeout: const Duration(seconds: 30));
  });

  await shot('01_default_1280.png');

  await guarded('maximize window', () async {
    await win('maximize');
    await Future<void>.delayed(const Duration(milliseconds: 800));
    return true;
  });
  await shot('02_maximized.png');

  await guarded('resize 1920x1080', () async {
    await win('size', 1920, 1080);
    return true;
  });
  await shot('03_size_1920x1080.png');

  await guarded('resize 2560x1440', () async {
    await win('size', 2560, 1440);
    return true;
  });
  await shot('04_size_2560x1440.png');

  await guarded('restore 1280x720', () async {
    await win('size', 1280, 720);
    return true;
  });
  await shot('05_restore_1280x720.png');

  say('DONE');
  await driver.close();
}
