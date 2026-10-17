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

  test('普通日志立即可读、Unicode 与追加顺序正确、关闭后释放文件', () async {
    var errors = <FileSystemException>[];
    var output = BTDurableLogOutput(
      directory.path,
      'unit',
      identity: identity,
      onError: errors.add,
    );
    var file = File(identity.filePath(directory.path, 'unit', DateTime.now()));
    try {
      output.output(OutputEvent(LogEvent(Level.info, 'first'), ['中文记录']));
      expect(await file.readAsString(), '中文记录\n');
      output.output(
        OutputEvent(LogEvent(Level.warning, 'second'), ['警告', '详情']),
      );
      expect(await file.readAsString(), '中文记录\n警告\n详情\n');
    } finally {
      await output.destroy();
    }
    expect(errors, isEmpty);
    await file.rename('${file.path}.closed');
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
