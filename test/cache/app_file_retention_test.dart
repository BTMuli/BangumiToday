// Dart imports:
import 'dart:io';

// Package imports:
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

// Project imports:
import 'package:bangumi_today/core/cache/app_file_retention.dart';

void main() {
  const retention = AppFileRetention();
  var now = DateTime.utc(2026, 11, 10, 12);
  late Directory root;
  var fixtureRoot = Directory(
    path.join(Directory.current.path, 'temp', 'data-retention-tests'),
  );

  setUp(() async {
    await fixtureRoot.create(recursive: true);
    root = await fixtureRoot.createTemp('case-');
  });

  tearDown(() async {
    expect(
      path.isWithin(fixtureRoot.absolute.path, root.absolute.path),
      isTrue,
    );
    if (await root.exists()) await root.delete(recursive: true);
  });

  tearDownAll(() async {
    if (await fixtureRoot.exists() && await fixtureRoot.list().isEmpty) {
      await fixtureRoot.delete();
    }
  });

  Future<File> fileAt(String name, DateTime modified) async {
    var file = File(path.join(root.path, name));
    await file.create(recursive: true);
    await file.writeAsString('fixture');
    await file.setLastModified(modified);
    return file;
  }

  Future<Directory> interruptedAt(String name, DateTime modified) async {
    var relative = path.join('11.3.0.99', name);
    await fileAt(path.join(relative, 'nested', 'component.dll'), modified);
    var directory = Directory(path.join(root.path, relative));
    return directory;
  }

  test('迁移备份到 30 天边界删除，近期备份和其他文件保留', () async {
    var cutoff = now.subtract(const Duration(days: 30));
    var expired = await fileAt('BangumiToday.pre-migration-1.db', cutoff);
    var recent = await fileAt(
      'BangumiToday.pre-migration-2.db',
      cutoff.add(const Duration(seconds: 1)),
    );
    var unrelated = await fileAt('manual-backup.db', cutoff);
    await retention.pruneBackups(root, now: now);
    expect(await expired.exists(), isFalse);
    expect(await recent.exists(), isTrue);
    expect(await unrelated.exists(), isTrue);
  });

  test('下载包和 ETag 成组保留 14 天，跳过正在更新和非应用文件', () async {
    var cutoff = now.subtract(const Duration(days: 14));
    var expiredName = 'downloads/${'a' * 64}.7z.part';
    var currentName = 'downloads/${'b' * 64}.7z.part';
    var expired = await fileAt(expiredName, cutoff);
    var expiredEtag = await fileAt('$expiredName.etag', cutoff);
    var current = await fileAt(
      currentName,
      cutoff.add(const Duration(seconds: 1)),
    );
    var currentEtag = await fileAt('$currentName.etag', cutoff);
    var orphan = await fileAt('downloads/${'c' * 64}.7z.part.etag', cutoff);
    var unrelated = await fileAt('downloads/manual.7z', cutoff);
    var runtime = await fileAt('11.3.0.99/sm86/component.dll', cutoff);
    var engine = await fileAt('engines/keep.engine', cutoff);

    await retention.pruneDownloads(root, now: now);
    expect(await expired.exists(), isFalse);
    expect(await expiredEtag.exists(), isFalse);
    expect(await orphan.exists(), isFalse);
    expect(await current.exists(), isTrue);
    expect(await currentEtag.exists(), isTrue);
    expect(await unrelated.exists(), isTrue);
    expect(await runtime.exists(), isTrue);
    expect(await engine.exists(), isTrue);
  });

  test('安装持锁时跳过全部下载残留，释放锁后重试', () async {
    var cutoff = now.subtract(const Duration(days: 14));
    var expired = await fileAt('downloads/${'a' * 64}.7z.part', cutoff);
    var lock = await File(
      path.join(root.path, 'install.lock'),
    ).open(mode: FileMode.append);
    await lock.lock(FileLock.exclusive);
    try {
      await retention.pruneDownloads(root, now: now);
      expect(await expired.exists(), isTrue);
    } finally {
      await lock.unlock();
      await lock.close();
    }
    await retention.pruneDownloads(root, now: now);
    expect(await expired.exists(), isFalse);
  }, skip: !Platform.isWindows);

  test('跨进程遗留的解压目录保留 14 天，近期文件和运行时目录不清理', () async {
    var created = DateTime.now();
    var future = created.add(const Duration(days: 16));
    var stale = await interruptedAt(
      'sm86.staging-999-1-interrupted-999',
      created,
    );
    var invalid = await interruptedAt('sm86.invalid-999-2', created);
    var current = await interruptedAt(
      'sm86.staging-999-3',
      created.add(const Duration(days: 15)),
    );
    var unrelated = await interruptedAt('sm86.staging-manual', created);
    var runtime = await fileAt('11.3.0.99/sm86/component.dll', created);

    await retention.pruneDownloads(root, now: future);
    expect(await stale.exists(), isFalse);
    expect(await invalid.exists(), isFalse);
    expect(await current.exists(), isTrue);
    expect(await unrelated.exists(), isTrue);
    expect(await runtime.exists(), isTrue);
  });

  test('下载清理不跟随符号链接到外部目录', () async {
    var outside = await fixtureRoot.createTemp('outside-');
    addTearDown(() async {
      expect(
        path.isWithin(fixtureRoot.absolute.path, outside.absolute.path),
        isTrue,
      );
      await outside.delete(recursive: true);
    });
    var file = File(path.join(outside.path, '${'a' * 64}.7z.part'));
    await file.writeAsString('external');
    await file.setLastModified(now.subtract(const Duration(days: 15)));
    var link = Link(path.join(root.path, 'downloads'));
    try {
      await link.create(outside.path);
    } on FileSystemException {
      markTestSkipped('当前环境不允许创建符号链接');
      return;
    }
    await expectLater(
      retention.pruneDownloads(root, now: now),
      throwsA(isA<FileSystemException>()),
    );
    expect(await file.readAsString(), 'external');
  });
}
