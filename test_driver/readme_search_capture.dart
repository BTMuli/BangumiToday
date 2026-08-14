// Dart imports:
import 'dart:io';

// Package imports:
import 'package:flutter_driver/flutter_driver.dart';

Future<void> main(List<String> args) async {
  var d = await FlutterDriver.connect(dartVmServiceUrl: args[0]);
  await d.setSemantics(true);
  var out = Directory(args.length > 1 ? args[1] : 'build/readme_preview_1280');
  out.createSync(recursive: true);
  var log = File('${out.path}/search_capture.log');
  void say(String s) => log.writeAsStringSync('$s\n', mode: FileMode.append);
  Future<bool> has(SerializableFinder f) async {
    try {
      await d.waitFor(f, timeout: const Duration(seconds: 3));
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> tap(SerializableFinder f, String name) async {
    if (!await has(f)) {
      say('MISSING $name');
      return;
    }
    await d.tap(f, timeout: const Duration(seconds: 10));
    await Future<void>.delayed(const Duration(seconds: 1));
    say('TAP $name');
  }

  Future<void> shot(String name) async {
    File('${out.path}/$name').writeAsBytesSync(await d.screenshot());
    say('SHOT $name');
  }

  Future<void> nativeClick(int x, int y) async {
    await Process.run('powershell', <String>[
      '-NoProfile',
      '-ExecutionPolicy',
      'Bypass',
      '-File',
      'scripts/click_app.ps1',
      '$x',
      '$y',
    ]);
    await Future<void>.delayed(const Duration(milliseconds: 900));
  }

  await tap(find.bySemanticsLabel(RegExp(r'^Bangumi-今日放送')), 'home');
  await nativeClick(1110, 30);
  say('SEARCH_PAGE ${await has(find.text('Bangumi-条目搜索'))}');
  var field = find.byType('EditableText');
  await tap(field, 'field');
  await d.enterText('葬送的芙莉莲');
  await d.sendTextInputAction(TextInputAction.search);
  await Future<void>.delayed(const Duration(seconds: 5));
  await shot('subjectSearchGrid.png');
  say('TITLE ${await has(find.text('Bangumi-条目搜索'))}');
  await d.close();
}
