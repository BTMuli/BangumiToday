// Test: does native mouse-wheel scrolling move the settings ListView?
import 'dart:io';

import 'package:flutter_driver/flutter_driver.dart';

Future<void> main(List<String> args) async {
  final out = File('test_driver/wheel_test.log');
  if (out.existsSync()) out.deleteSync();
  void say(String s) {
    out.writeAsStringSync('$s\n', mode: FileMode.append);
    stdout.writeln(s);
    stdout.flush();
  }

  final driver = await FlutterDriver.connect(
    dartVmServiceUrl: args[0],
    timeout: const Duration(seconds: 60),
  );
  say('CONNECTED');

  Future<void> shot(String name) async {
    final png = await driver.screenshot().timeout(const Duration(seconds: 30));
    File('build/verify_shots2/$name').writeAsBytesSync(png);
    say('SHOT $name (${png.length} bytes)');
  }

  await shot('wheel_00_before.png');

  final r = await Process.run('powershell', <String>[
    '-NoProfile',
    '-ExecutionPolicy', 'Bypass',
    '-File',
    'D:/Code/App/bangumi_today/scripts/scroll_app.ps1',
    'up', '12',
  ]);
  say('WHEEL UP rc=${r.exitCode} out=${(r.stdout as String).trim()} err=${(r.stderr as String).trim()}');

  await Future<void>.delayed(const Duration(milliseconds: 1500));
  await shot('wheel_01_after_up.png');

  final r2 = await Process.run('powershell', <String>[
    '-NoProfile',
    '-ExecutionPolicy', 'Bypass',
    '-File',
    'D:/Code/App/bangumi_today/scripts/scroll_app.ps1',
    'down', '12',
  ]);
  say('WHEEL DOWN rc=${r2.exitCode} out=${(r2.stdout as String).trim()} err=${(r2.stderr as String).trim()}');

  await Future<void>.delayed(const Duration(milliseconds: 1500));
  await shot('wheel_02_after_down.png');
  say('DONE');
  driver.close();
}
