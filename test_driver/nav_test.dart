// Quick test: tap the settings pane entry via semantics regex.
import 'dart:io';

import 'package:flutter_driver/flutter_driver.dart';

Future<void> main(List<String> args) async {
  final out = File('test_driver/nav_test.log');
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
  await driver.setSemantics(true);
  say('SEMANTICS ON');

  final patterns = <Pattern>[
    RegExp(r'^应用设置'),
    RegExp(r'应用设置$'),
    RegExp(r'^更多设置'),
    '应用设置',
    RegExp(r'设置'),
  ];
  var tapped = false;
  for (final p in patterns) {
    try {
      await driver.tap(find.bySemanticsLabel(p), timeout: const Duration(seconds: 15));
      say('TAPPED via ${p.runtimeType} $p');
      tapped = true;
      break;
    } catch (e) {
      say('tap ${p.runtimeType} $p failed: $e');
    }
  }

  if (!tapped) {
    say('NO TAP SUCCEEDED');
  }

  try {
    await driver.waitFor(find.text('配置应用、下载引擎与 Bangumi 账号'),
        timeout: const Duration(seconds: 15));
    say('SETTINGS PAGE OPENED');
  } catch (e) {
    say('SETTINGS PAGE NOT OPENED: $e');
  }

  try {
    final png = await driver.screenshot().timeout(const Duration(seconds: 30));
    File('build/verify_shots2/nav_test.png').writeAsBytesSync(png);
    say('SHOT nav_test.png');
  } catch (e) {
    say('SHOT FAILED: $e');
  }

  say('DONE');
  driver.close();
}
