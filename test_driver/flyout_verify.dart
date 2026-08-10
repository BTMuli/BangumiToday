// Verification driver for the home page "more" flyout.
// Usage: dart run test_driver/flyout_verify.dart <vmServiceUrl> <outDir>

import 'dart:io';

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

  var moreButton = find.bySemanticsLabel(RegExp(r'^更多$'));
  var firstItem = find.text('查看用户收藏');

  var homeOk = await guarded('home page loaded', () async {
    return exists(find.text('星期一'), timeout: const Duration(seconds: 30));
  });
  if (!homeOk) {
    say('ABORT: home page not loaded');
    await driver.close();
    exit(1);
  }

  var moreOk = await guarded('more button found', () => exists(moreButton));
  if (!moreOk) {
    say('ABORT: more button not found');
    await driver.close();
    exit(1);
  }
  await shot('01_home_before_flyout.png');

  await driver.tap(moreButton).timeout(const Duration(seconds: 15));
  await Future<void>.delayed(const Duration(milliseconds: 800));
  var flyoutOk = await guarded(
    'flyout first item visible',
    () => exists(firstItem),
  );
  if (!flyoutOk) {
    say('ABORT: flyout did not open');
    await driver.close();
    exit(1);
  }

  var buttonTopLeft = await driver.getTopLeft(moreButton);
  var buttonBottomLeft = await driver.getBottomLeft(moreButton);
  var itemTopLeft = await driver.getTopLeft(firstItem);
  say('BUTTON top-left => ${buttonTopLeft.dx},${buttonTopLeft.dy}');
  say('BUTTON bottom-left => ${buttonBottomLeft.dx},${buttonBottomLeft.dy}');
  say('ITEM top-left => ${itemTopLeft.dx},${itemTopLeft.dy}');
  var gap = itemTopLeft.dy - buttonBottomLeft.dy;
  say('GAP button-bottom -> item-top = $gap');
  await shot('02_flyout_open.png');

  say('DONE');
  await driver.close();
}
