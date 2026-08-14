// Dart imports:
import 'dart:io';

// Package imports:
import 'package:flutter_driver/flutter_driver.dart';

Future<void> main(List<String> args) async {
  var url = args[0];
  var outDir = Directory(
    args.length > 1 ? args[1] : 'build/readme_preview_1280',
  );
  outDir.createSync(recursive: true);
  var log = File('${outDir.path}/capture.log');
  if (log.existsSync()) log.deleteSync();

  void say(String value) {
    log.writeAsStringSync('$value\n', mode: FileMode.append);
    stdout.writeln(value);
    stdout.flush();
  }

  var driver = await FlutterDriver.connect(
    dartVmServiceUrl: url,
    timeout: const Duration(seconds: 30),
  );
  await driver.setSemantics(true);
  say('CONNECTED');

  Future<bool> exists(SerializableFinder finder) async {
    try {
      await driver.waitFor(finder, timeout: const Duration(seconds: 3));
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> shot(String name) async {
    var bytes = await driver.screenshot().timeout(const Duration(seconds: 20));
    File('${outDir.path}/$name').writeAsBytesSync(bytes);
    say('SHOT $name ${bytes.length}');
  }

  Future<bool> tapSem(String label) async {
    var finder = find.bySemanticsLabel(RegExp('^$label'));
    if (!await exists(finder)) {
      say('MISSING $label');
      return false;
    }
    try {
      await driver.tap(finder, timeout: const Duration(seconds: 10));
      say('TAP $label');
      await Future<void>.delayed(const Duration(milliseconds: 800));
      return true;
    } catch (e) {
      say('TAP_FAIL $label $e');
      return false;
    }
  }

  Future<bool> tapText(String text) async {
    var finder = find.text(text);
    if (!await exists(finder)) {
      say('MISSING_TEXT $text');
      return false;
    }
    try {
      await driver.tap(finder, timeout: const Duration(seconds: 10));
      say('TAP_TEXT $text');
      await Future<void>.delayed(const Duration(milliseconds: 800));
      return true;
    } catch (e) {
      say('TAP_TEXT_FAIL $text $e');
      return false;
    }
  }

  Future<void> page(String name, String title) async {
    var visible = await exists(find.text(title));
    say('PAGE $name title=$visible');
    if (visible) await shot(name);
  }

  say('HOME=${await exists(find.text('星期一'))}');
  await shot('calendar_raw.png');

  await tapSem('RSS & BMF');
  await page('rss_bmf', 'BMF');
  await shot('rss_bmf_raw.png');
  await tapText('Mikan');
  await page('mikan', 'Mikan');
  await tapText('Comicat');
  await page('comicat', 'Comicat');

  await tapSem('Bangumi-今日放送');
  await Future<void>.delayed(const Duration(milliseconds: 500));
  await tapSem('搜索条目');
  await page('subject_search', 'Bangumi-条目搜索');
  if (await exists(find.text('网格'))) {
    await tapText('网格');
    await shot('subject_search_grid_raw.png');
    await tapText('列表');
    await shot('subject_search_line_raw.png');
  } else {
    say('MISSING_SEARCH_LAYOUT_TOGGLE');
  }

  await tapSem('Bangumi-今日放送');
  await Future<void>.delayed(const Duration(milliseconds: 500));
  var detail = find.bySemanticsLabel(RegExp('查看详情'));
  if (await exists(detail)) {
    try {
      await driver.tap(detail, timeout: const Duration(seconds: 10));
      await Future<void>.delayed(const Duration(seconds: 2));
      say('TAP_DETAIL');
      await page('subject_detail', '条目详情');
      await shot('subject_detail_raw.png');
    } catch (e) {
      say('DETAIL_FAIL $e');
    }
  } else {
    say('MISSING_DETAIL');
  }

  await tapSem('应用设置');
  await page('app_settings', '应用设置');
  await shot('app_settings_raw.png');
  await tapSem('Bangumi-今日放送');
  await tapSem('下载管理');
  await page('download', '下载管理');
  await shot('download_raw.png');

  say('DONE');
  await driver.close();
}
