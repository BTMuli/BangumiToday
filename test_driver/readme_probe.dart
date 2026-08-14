// Dart imports:
import 'dart:io';

// Package imports:
import 'package:flutter_driver/flutter_driver.dart';

Future<void> main(List<String> args) async {
  var driver = await FlutterDriver.connect(
    dartVmServiceUrl: args[0],
    timeout: const Duration(seconds: 30),
  );
  await driver.setSemantics(true);
  var out = Directory(args.length > 1 ? args[1] : 'build/readme_preview_1280');
  out.createSync(recursive: true);
  var log = File('${out.path}/probe.log');
  void say(String s) {
    log.writeAsStringSync('$s\n', mode: FileMode.append);
  }

  Future<bool> has(SerializableFinder f) async {
    try {
      await driver.waitFor(f, timeout: const Duration(seconds: 2));
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> shot(String name) async {
    var b = await driver.screenshot();
    File('${out.path}/$name').writeAsBytesSync(b);
    say('SHOT $name ${b.length}');
  }

  Future<void> tapSem(String label) async {
    var f = find.bySemanticsLabel(RegExp('^$label'));
    say('HAS $label ${await has(f)}');
    if (await has(f)) {
      await driver.tap(f, timeout: const Duration(seconds: 10));
      await Future<void>.delayed(const Duration(milliseconds: 700));
    }
  }

  await tapSem('Bangumi-今日放送');
  await tapSem('搜索条目');
  await shot('probe_search.png');
  say('TEXT Bangumi-条目搜索 ${await has(find.text('Bangumi-条目搜索'))}');
  say('TEXT 搜索 ${await has(find.text('搜索'))}');
  say('TEXT 网格 ${await has(find.text('网格'))}');
  say('TEXT 列表 ${await has(find.text('列表'))}');
  say('TREE\n${(await driver.getRenderTree()).toString()}');
  await driver.close();
}
