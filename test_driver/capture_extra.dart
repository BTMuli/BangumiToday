// Capture precise views: very top of settings page and the download-limit rows.
import 'dart:io';

import 'package:flutter_driver/flutter_driver.dart';

const _wheelScript = 'D:/Code/App/bangumi_today/scripts/scroll_app.ps1';

Future<void> main(List<String> args) async {
  final out = File('test_driver/capture_extra.log');
  if (out.existsSync()) out.deleteSync();
  void say(String s) {
    out.writeAsStringSync('$s\n', mode: FileMode.append);
    try {
      stdout.writeln(s);
      stdout.flush();
    } catch (_) {}
  }

  final driver = await FlutterDriver.connect(
    dartVmServiceUrl: args[0],
    timeout: const Duration(seconds: 60),
  );
  say('CONNECTED');

  Future<void> wheel(String dir, int ticks) async {
    await Process.run('powershell', <String>[
      '-NoProfile',
      '-ExecutionPolicy', 'Bypass',
      '-File', _wheelScript,
      dir,
      '$ticks',
    ]);
    await Future<void>.delayed(const Duration(milliseconds: 300));
  }

  Future<void> shot(String name) async {
    final png = await driver.screenshot().timeout(const Duration(seconds: 30));
    File('build/verify_shots2/$name').writeAsBytesSync(png);
    say('SHOT $name (${png.length} bytes)');
  }

  Future<bool> exists(SerializableFinder f,
      {Duration t = const Duration(seconds: 2)}) async {
    try {
      await driver.waitFor(f, timeout: t);
      return true;
    } catch (_) {
      return false;
    }
  }

  // 1) very top: wheel up hard, then settle
  await wheel('up', 20);
  await Future<void>.delayed(const Duration(milliseconds: 600));
  await shot('extra_01_top.png');
  say('TOP captured, 应用配置 in tree: ${await exists(find.text('应用配置'))}');
  say('主题模式 in tree: ${await exists(find.text('主题模式'))}');

  // 2) download limit rows: scroll down until the row area fills the view
  for (var i = 0; i < 16; i++) {
    await wheel('down', 4);
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }
  await Future<void>.delayed(const Duration(milliseconds: 400));
  await shot('extra_02_download_limits.png');
  say('磁力元数据超时 in tree: ${await exists(find.text('磁力元数据超时（秒）'))}');
  say('同时下载任务数 in tree: ${await exists(find.text('同时下载任务数'))}');
  await wheel('down', 4);
  await Future<void>.delayed(const Duration(milliseconds: 400));
  await shot('extra_03_download_more.png');
  say('做种分享率 in tree: ${await exists(find.text('做种分享率'))}');

  say('DONE');
  driver.close();
}
