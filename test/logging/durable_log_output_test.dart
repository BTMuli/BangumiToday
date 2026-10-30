// Dart imports:
import 'dart:io';

// Package imports:
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';

// Project imports:
import 'package:bangumi_today/tools/durable_log_output.dart';
import 'package:bangumi_today/tools/log_identity.dart';

void main() {
  var root = Directory('temp/log-output-check');
  late Directory directory;
  late BTLogIdentity identity;

  setUp(() async {
    await root.create(recursive: true);
    directory = await root.createTemp('run-');
    identity = BTLogIdentity(DateTime.now(), pid);
  });
  tearDown(() => directory.delete(recursive: true));
  tearDownAll(() async {
    if (await root.exists() && await root.list().isEmpty) await root.delete();
  });

  test('紧凑日志立即可读、Unicode 与追加顺序正确、关闭后释放文件', () async {
    var errors = <FileSystemException>[];
    var output = BTDurableLogOutput(
      directory.path,
      'unit',
      identity: identity,
      onError: errors.add,
    );
    var file = File(identity.filePath(directory.path, 'unit', DateTime.now()));
    var time = DateTime(2026, 10, 30, 9, 0, 0, 123);
    var printer = PrettyPrinter(colors: false);
    var first = LogEvent(Level.info, '中文记录', time: time);
    var second = LogEvent(Level.warning, '警告\n详情', time: time);
    try {
      output.output(OutputEvent(first, printer.log(first)));
      expect(
        await file.readAsString(),
        '[I] TIME: 2026-10-30T09:00:00.123 中文记录\n',
      );
      output.output(OutputEvent(second, printer.log(second)));
      expect(
        await file.readAsString(),
        '[I] TIME: 2026-10-30T09:00:00.123 中文记录\n'
        '[W] TIME: 2026-10-30T09:00:00.123 警告\n详情\n',
      );
    } finally {
      await output.destroy();
    }
    expect(errors, isEmpty);
    await file.rename('${file.path}.closed');
  });

  test('紧凑错误日志保留异常和显式调用栈', () async {
    var errors = <FileSystemException>[];
    var output = BTDurableLogOutput(
      directory.path,
      'unit',
      identity: identity,
      onError: errors.add,
    );
    var file = File(identity.filePath(directory.path, 'unit', DateTime.now()));
    var event = LogEvent(
      Level.error,
      '操作失败',
      time: DateTime(2026, 10, 30, 9),
      error: StateError('broken'),
      stackTrace: StackTrace.fromString('#0 failingOperation\n#1 caller'),
    );
    try {
      output.output(OutputEvent(event, PrettyPrinter().log(event)));
      expect(
        await file.readAsString(),
        '[E] TIME: 2026-10-30T09:00:00.000 操作失败'
        '  ERROR: Bad state: broken\n#0 failingOperation\n#1 caller\n',
      );
    } finally {
      await output.destroy();
    }
    expect(errors, isEmpty);
  });

  test('文件系统失败交给回调，日志输出不会递归或抛出异常', () async {
    var blocked = File('${directory.path}/not-a-directory');
    await blocked.writeAsString('occupied');
    var errors = <FileSystemException>[];
    var output = BTDurableLogOutput(
      blocked.path,
      'unit',
      identity: identity,
      onError: errors.add,
    );
    output.output(OutputEvent(LogEvent(Level.error, 'failure'), ['entry']));
    expect(errors, hasLength(1));
    await output.destroy();
  });
}
