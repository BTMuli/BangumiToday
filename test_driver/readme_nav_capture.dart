// Dart imports:
import 'dart:io';

// Package imports:
import 'package:flutter_driver/flutter_driver.dart';

Future<void> main(List<String> args) async {
  var d = await FlutterDriver.connect(dartVmServiceUrl: args[0]);
  var out = Directory(args.length > 1 ? args[1] : 'build/readme_preview_1280');
  out.createSync(recursive: true);
  Future<void> click(int x, int y) async {
    await Process.run('powershell', <String>[
      '-NoProfile',
      '-ExecutionPolicy',
      'Bypass',
      '-File',
      'scripts/click_app.ps1',
      '$x',
      '$y',
    ]);
    await Future<void>.delayed(const Duration(milliseconds: 800));
  }

  Future<void> shot(String name) async {
    File('${out.path}/$name').writeAsBytesSync(await d.screenshot());
  }

  await d.setSemantics(true);
  await click(35, 180);
  await shot('userCollection.png');
  await click(35, 126);
  await shot('bmf.png');
  await click(35, 72);
  await shot('calendar.png');
  await d.close();
}
