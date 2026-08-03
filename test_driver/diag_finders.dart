// Diagnostic: test which finders resolve on the running app.
// Usage: dart run test_driver/diag_finders.dart <vmServiceUrl>
import 'dart:io';

import 'package:flutter_driver/flutter_driver.dart';

Future<void> main(List<String> args) async {
  final out = File('test_driver/diag_out.log');
  if (out.existsSync()) out.deleteSync();
  void say(String s) {
    out.writeAsStringSync('$s\n', mode: FileMode.append);
    stdout.writeln(s);
    stdout.flush();
  }

  final url = args[0];
  final driver = await FlutterDriver.connect(
    dartVmServiceUrl: url,
    timeout: const Duration(seconds: 60),
  );
  say('CONNECTED');
  await driver.setSemantics(true);
  say('SEMANTICS ENABLED');

  Future<bool> has(
    SerializableFinder f, {
    Duration t = const Duration(seconds: 8),
  }) async {
    try {
      await driver.waitFor(f, timeout: t);
      return true;
    } catch (e) {
      return false;
    }
  }

  say('text 星期一: ${await has(find.text('星期一'))}');
  say('text 应用设置: ${await has(find.text('应用设置'))}');
  say('type Text: ${await has(find.byType('Text'))}');
  say('type NavigationView: ${await has(find.byType('NavigationView'))}');
  say('type Icon: ${await has(find.byType('Icon'))}');
  say('semantics 应用设置: ${await has(find.bySemanticsLabel('应用设置'))}');
  say('semantics 星期一: ${await has(find.bySemanticsLabel('星期一'))}');
  say('semantics regex 设置: ${await has(find.bySemanticsLabel(RegExp('设置')))}');
  say('semantics regex ^应用设置: ${await has(find.bySemanticsLabel(RegExp('^应用设置')))}');
  say('semantics regex 应用设置\$: ${await has(find.bySemanticsLabel(RegExp(r'应用设置$')))}');
  say('semantics regex ^更多设置: ${await has(find.bySemanticsLabel(RegExp('^更多设置')))}');
  say('semantics regex ^设置\$: ${await has(find.bySemanticsLabel(RegExp(r'^设置$')))}');

  for (final label in <String>['设置', '更多设置', '应用设置']) {
    try {
      final id = await driver.getSemanticsId(find.bySemanticsLabel(label));
      say('getSemanticsId exact "$label" => $id');
    } catch (e) {
      say('getSemanticsId exact "$label" ERROR: $e');
    }
  }

  try {
    final tree = await driver.getRenderTree();
    final s = tree.toString();
    say('RENDER TREE LEN: ${s.length}');
    say('contains 应用设置: ${s.contains('应用设置')}');
    say('contains 星期一: ${s.contains('星期一')}');
    say('contains Text: ${s.contains('Text')}');
    say(s.substring(0, s.length < 3500 ? s.length : 3500));
  } catch (e) {
    say('render tree error: $e');
  }

  say('DONE');
  driver.close();
}
