// Verification driver for the home page toolbar.
// Usage: dart run test_driver/flyout_verify.dart <vmServiceUrl> <outDir>

// Dart imports:
import 'dart:io';

// Package imports:
import 'package:flutter_driver/flutter_driver.dart';

Future<void> main(List<String> args) async {
  var vmUrl = args.isNotEmpty
      ? args[0]
      : Platform.environment['VM_SERVICE_URL'];
  var outDir = args.length > 1 ? args[1] : Directory.current.path;
  var logFile = File('$outDir/flyout_verify.log');
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

  Future<bool> guarded(String label, Future<bool> Function() action) async {
    try {
      var ok = await action().timeout(const Duration(seconds: 60));
      say(ok ? 'PASS $label' : 'FAIL $label');
      return ok;
    } catch (e) {
      say('FAIL $label => $e');
      return false;
    }
  }

  var homeOk = await guarded('home page loaded', () async {
    return exists(find.text('星期一'), timeout: const Duration(seconds: 30));
  });
  if (!homeOk) {
    say('ABORT: home page not loaded');
    await driver.close();
    exit(1);
  }

  var dataOk = await guarded(
    'bangumi data update button found',
    () => exists(find.bySemanticsLabel(RegExp(r'^更新 BangumiData'))),
  );
  var moreGone = await guarded(
    'more button removed',
    () async => !await exists(
      find.bySemanticsLabel(RegExp(r'^更多$')),
      timeout: const Duration(seconds: 2),
    ),
  );
  var collectionGone = await guarded(
    'collection jump removed',
    () async =>
        !await exists(find.text('查看用户收藏'), timeout: const Duration(seconds: 2)),
  );
  await shot('01_home_toolbar.png');

  say('DONE');
  await driver.close();
  if (!dataOk || !moreGone || !collectionGone) exit(1);
}
