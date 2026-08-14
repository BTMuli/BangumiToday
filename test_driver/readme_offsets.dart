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
  var out = File(
    args.length > 1 ? args[1] : 'build/readme_preview_1280/offsets.log',
  );
  void say(String s) {
    out.writeAsStringSync('$s\n', mode: FileMode.append);
  }

  Future<void> probe(String name, SerializableFinder f) async {
    try {
      var top = await d.getTopLeft(f, timeout: const Duration(seconds: 3));
      var bottom = await d.getBottomRight(
        f,
        timeout: const Duration(seconds: 3),
      );
      say('$name ${top.dx},${top.dy} -> ${bottom.dx},${bottom.dy}');
    } catch (e) {
      say('$name ERROR $e');
    }
  }

  await probe('calendar', find.bySemanticsLabel(RegExp(r'^Bangumi-今日放送')));
  await probe('rss', find.bySemanticsLabel(RegExp(r'^RSS & BMF')));
  await probe('user', find.bySemanticsLabel(RegExp(r'^未登录|^\w')));
  await probe('search', find.bySemanticsLabel(RegExp(r'^搜索条目')));
  await probe('detail', find.bySemanticsLabel(RegExp(r'查看详情')));
  await probe('settings', find.bySemanticsLabel(RegExp(r'^应用设置')));
  await d.close();
}
