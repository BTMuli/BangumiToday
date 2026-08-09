// Temporary verification driver for the settings page redesign.
// Usage: dart run test_driver/settings_verify.dart <vmServiceUrl> <outDir>
import 'dart:io';

import 'package:flutter_driver/flutter_driver.dart';

Future<void> main(List<String> args) async {
  var vmUrl = args.isNotEmpty
      ? args[0]
      : Platform.environment['VM_SERVICE_URL'];
  var outDir = args.length > 1 ? args[1] : Directory.current.path;
  void say(String s) {
    File(
      '$outDir/settings_verify.log',
    ).writeAsStringSync('$s\n', mode: FileMode.append);
  }

  if (vmUrl == null) {
    say('No VM service URL provided.');
    exit(2);
  }

  var driver = await FlutterDriver.connect(
    dartVmServiceUrl: vmUrl,
    timeout: const Duration(seconds: 60),
  );
  say('CONNECTED');

  Future<void> check(String label, String text) async {
    await driver.waitFor(find.text(text), timeout: const Duration(seconds: 20));
    say('OK $label => $text');
  }

  Future<void> shot(String name) async {
    var png = await driver.screenshot().timeout(const Duration(seconds: 30));
    File('$outDir/$name').writeAsBytesSync(png);
    say('SHOT $name (${png.length} bytes)');
  }

  Future<void> guarded(String label, Future<void> Function() action) async {
    try {
      await action().timeout(const Duration(seconds: 30));
      say('PASS $label');
    } catch (e) {
      say('FAIL $label => $e');
    }
  }

  await guarded('导航到设置页', () async {
    say('STEP tap 应用设置');
    await driver.tap(find.text('应用设置'));
    await check('页面头部标题', '应用设置');
    await check('页面头部副标题', '配置应用、下载引擎与 Bangumi 账号');
  });

  await guarded('分区与子项检查', () async {
    await check('Bangumi 分区', 'Bangumi 配置');
    await check('Bangumi 分区子项', '用户信息');
    await check('设备分区', '设备信息');
    await check('设备分区子项', '所在平台');
    await check('下载分区', '下载引擎');
    await check('下载分区子项', '启用下载引擎');
    await check('应用分区', '应用配置');
    await check('应用分区子项', '主题模式');
    await check('徽章标题', 'BangumiToday');
    await check('徽章按钮', 'GitHub 仓库');
  });

  await guarded('整页截图', () async {
    await shot('settings_full.png');
  });

  await guarded('折叠设备分区', () async {
    say('STEP collapse 设备信息');
    await driver.tap(find.text('设备信息'));
    await driver.waitForAbsent(
      find.text('所在平台'),
      timeout: const Duration(seconds: 10),
    );
    await shot('settings_collapsed.png');
  });

  await guarded('展开设备分区', () async {
    say('STEP expand 设备信息');
    await driver.tap(find.text('设备信息'));
    await driver.waitFor(
      find.text('所在平台'),
      timeout: const Duration(seconds: 10),
    );
    await shot('settings_expanded.png');
  });

  say('DONE');
}
