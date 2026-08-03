// Verification driver for the beautified settings page.
// Uses native mouse-wheel scrolling (scripts/scroll_app.ps1) because
// desktop Flutter ignores synthetic touch drags on this ListView.
// Usage: dart run test_driver/verify_settings_fresh.dart <vmServiceUrl> <outDir>
import 'dart:io';

import 'package:flutter_driver/flutter_driver.dart';

const _wheelScript = 'D:/Code/App/bangumi_today/scripts/scroll_app.ps1';

Future<void> main(List<String> args) async {
  final vmUrl =
      args.isNotEmpty ? args[0] : Platform.environment['VM_SERVICE_URL'];
  final outDir = args.length > 1 ? args[1] : Directory.current.path;
  final logFile = File('$outDir/verify_fresh.log');
  if (logFile.existsSync()) logFile.deleteSync();

  void say(String s) {
    final line = '[${DateTime.now().toIso8601String().substring(11, 19)}] $s';
    logFile.writeAsStringSync('$line\n', mode: FileMode.append);
    try {
      stdout.writeln(line);
      stdout.flush();
    } catch (_) {}
  }

  if (vmUrl == null) {
    say('No VM service URL provided.');
    exit(2);
  }

  final driver = await FlutterDriver.connect(
    dartVmServiceUrl: vmUrl,
    timeout: const Duration(seconds: 60),
  );
  say('CONNECTED');
  await driver.setSemantics(true);
  say('SEMANTICS ENABLED');

  Future<bool> exists(
    SerializableFinder finder, {
    Duration timeout = const Duration(seconds: 4),
  }) async {
    try {
      await driver.waitFor(finder, timeout: timeout);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> waitVisible(
    String text, {
    Duration timeout = const Duration(seconds: 20),
  }) async {
    try {
      await driver.waitFor(find.text(text), timeout: timeout);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> shot(String name) async {
    final png = await driver.screenshot().timeout(const Duration(seconds: 30));
    File('$outDir/$name').writeAsBytesSync(png);
    say('SHOT $name (${png.length} bytes)');
  }

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

  Future<bool> wheelTo(
    SerializableFinder finder, {
    bool tappable = false,
  }) async {
    for (final dir in <String>['down', 'up']) {
      for (var i = 0; i < 12; i++) {
        if (await exists(finder, timeout: const Duration(seconds: 2))) {
          if (!tappable) return true;
          try {
            await driver.waitForTappable(finder,
                timeout: const Duration(seconds: 2));
            return true;
          } catch (_) {}
        }
        await wheel(dir, 8);
      }
    }
    return false;
  }

  Future<bool> guarded(
    String label,
    Future<bool> Function() action,
  ) async {
    try {
      final ok = await action().timeout(const Duration(seconds: 180));
      say(ok ? 'PASS $label' : 'FAIL $label');
      return ok;
    } catch (e) {
      say('FAIL $label => $e');
      return false;
    }
  }

  Future<bool> ensureDeviceExpanded() async {
    if (!await wheelTo(find.text('设备信息'), tappable: true)) return false;
    if (!await exists(find.text('所在平台'), timeout: const Duration(seconds: 3))) {
      try {
        await driver.tap(find.text('设备信息'));
      } catch (_) {}
      await Future<void>.delayed(const Duration(milliseconds: 800));
    }
    return waitVisible('所在平台', timeout: const Duration(seconds: 10));
  }

  // --- baseline ---
  await shot('fresh_01_current.png');

  // --- navigate to settings page ---
  final onSettings = await exists(find.text('配置应用、下载引擎与 Bangumi 账号'));
  if (!onSettings) {
    final bySemantics = find.bySemanticsLabel(RegExp(r'^应用设置'));
    if (await exists(bySemantics)) {
      await driver.tap(bySemantics);
      say('TAPPED semantics ^应用设置');
    } else if (await exists(find.byTooltip('应用设置'))) {
      await driver.tap(find.byTooltip('应用设置'));
      say('TAPPED tooltip 应用设置');
    } else {
      say('NO settings entry found');
    }
  } else {
    say('ALREADY on settings page');
  }

  await guarded('navigate to settings', () async {
    final ok1 = await waitVisible('应用设置');
    final ok2 = await waitVisible('配置应用、下载引擎与 Bangumi 账号');
    return ok1 && ok2;
  });

  await shot('fresh_02_settings_top.png');

  // --- badge (only when window width >= 1000) ---
  await guarded('app badge', () async {
    final ok1 = await exists(find.text('BangumiToday'));
    final ok2 = await exists(find.text('GitHub 仓库'));
    return ok1 && ok2;
  });

  // --- sections and key children ---
  final sections = <String, List<String>>{
    '应用配置': ['主题模式', '下载目录'],
    '下载引擎': ['启用下载引擎'],
    '设备信息': ['所在平台'],
    'Bangumi 配置': ['授权信息'],
  };
  for (final entry in sections.entries) {
    await guarded('section ${entry.key}', () async {
      if (entry.key == '设备信息') {
        return ensureDeviceExpanded();
      }
      if (!await wheelTo(find.text(entry.key))) return false;
      var ok = true;
      for (final child in entry.value) {
        if (!await exists(find.text(child), timeout: const Duration(seconds: 3))) {
          await wheelTo(find.text(child));
        }
        ok = await waitVisible(child, timeout: const Duration(seconds: 5)) && ok;
      }
      return ok;
    });
  }

  await shot('fresh_05_settings_bangumi.png');

  // --- collapse / expand 设备信息 ---
  await guarded('collapse 设备信息', () async {
    final expanded = await ensureDeviceExpanded();
    if (!expanded) return false;
    await driver.tap(find.text('设备信息'));
    await Future<void>.delayed(const Duration(milliseconds: 600));
    final gone = !await exists(find.text('所在平台'), timeout: const Duration(seconds: 10));
    await shot('fresh_03_device_collapsed.png');
    return gone;
  });

  await guarded('expand 设备信息', () async {
    if (!await wheelTo(find.text('设备信息'), tappable: true)) return false;
    await driver.tap(find.text('设备信息'));
    await Future<void>.delayed(const Duration(milliseconds: 800));
    final back = await waitVisible('所在平台', timeout: const Duration(seconds: 10));
    await shot('fresh_04_device_expanded.png');
    return back;
  });

  // --- extra shots for layout review ---
  await guarded('top section shot', () async {
    final ok = await wheelTo(find.text('应用配置'));
    await waitVisible('应用配置', timeout: const Duration(seconds: 8));
    await shot('fresh_06_app_config_top.png');
    return ok;
  });

  await guarded('download section shot', () async {
    final ok = await wheelTo(find.text('下载引擎'));
    await waitVisible('下载引擎', timeout: const Duration(seconds: 8));
    await shot('fresh_07_download.png');
    return ok;
  });

  say('DONE');
  driver.close();
}
