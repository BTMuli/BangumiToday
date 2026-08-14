// Dart imports:
import 'dart:io';

// Package imports:
import 'package:flutter_driver/flutter_driver.dart';

Future<void> main(List<String> args) async {
  var d = await FlutterDriver.connect(
    dartVmServiceUrl: args[0],
    timeout: const Duration(seconds: 30),
  );
  await d.setSemantics(true);
  var dir = Directory(args.length > 1 ? args[1] : 'build/readme_preview_1280');
  dir.createSync(recursive: true);
  var log = File('${dir.path}/current.log');
  void say(String s) => log.writeAsStringSync('$s\n', mode: FileMode.append);
  Future<bool> has(SerializableFinder f) async {
    try {
      await d.waitFor(f, timeout: const Duration(seconds: 3));
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> shot(String name) async {
    File('${dir.path}/$name').writeAsBytesSync(await d.screenshot());
    say('SHOT $name');
  }

  Future<void> tap(SerializableFinder f, String name) async {
    if (!await has(f)) {
      say('MISSING $name');
      return;
    }
    await d.tap(f, timeout: const Duration(seconds: 10));
    await Future<void>.delayed(const Duration(milliseconds: 900));
    say('TAP $name');
  }

  var navHome = find.bySemanticsLabel(RegExp(r'^Bangumi-今日放送'));
  var navBmf = find.bySemanticsLabel(RegExp(r'^RSS & BMF'));
  var navSettings = find.bySemanticsLabel(RegExp(r'^应用设置'));
  var navDownload = find.bySemanticsLabel(RegExp(r'^下载管理'));
  await tap(navHome, 'home');
  await shot('calendar.png');
  await tap(navBmf, 'bmf');
  await shot('bmf.png');
  var bmfTitle = find.text('落第贤者的学院无双～第二次转生的S级贤者～');
  var bmfCard = find.ancestor(
    of: bmfTitle,
    matching: find.byType('BmfCard'),
    firstMatchOnly: true,
  );
  if (await has(bmfTitle) && await has(bmfCard)) {
    await tap(bmfCard, 'bmf-card');
    await shot('bmf_detail.png');
  } else {
    say('MISSING bmf-card');
  }
  await tap(navHome, 'home-again');
  await tap(navSettings, 'settings');
  await shot('settings.png');
  await tap(navDownload, 'download');
  await shot('download.png');
  await d.close();
}
