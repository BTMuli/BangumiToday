// Dart imports:
import 'dart:math';

// Package imports:
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:bangumi_today/core/services/bt_engine/protocol.dart';
import 'package:bangumi_today/pages/download/download_file_pager.dart';

List<BtTaskFileDetail> _files(int count, {int paddingPerFile = 1}) => [
  for (var index = 0; index < count; index++) ...[
    BtTaskFileDetail(
      path: 'episode-$index.mkv',
      size: 100,
      completedBytes: 50,
      priority: 4,
    ),
    for (var pad = 0; pad < paddingPerFile; pad++)
      BtTaskFileDetail(
        path: '.pad/$index-$pad',
        size: 16,
        completedBytes: 0,
        priority: 0,
        paddingFile: true,
      ),
  ],
];

BtTaskFilesResult _window(List<BtTaskFileDetail> files, int offset, int limit) {
  var start = min(offset, files.length);
  var end = min(start + limit, files.length);
  return BtTaskFilesResult(
    files: files.sublist(start, end),
    truncated: end < files.length,
    totalFiles: files.length,
    offset: offset,
    totalContentFiles: files.where((file) => !file.isPadding).length,
    nextOffset: end < files.length ? end : null,
  );
}

void main() {
  test('208 条含 padding 的记录按 104 个真实文件分成三页', () async {
    var files = _files(104);
    var pager = DownloadFilePager();
    Future<BtTaskFilesResult> read(int offset, int limit) async =>
        _window(files, offset, limit);
    var first = await pager.load(readWindow: read);
    expect(first.totalFiles, 104);
    expect(first.files.length, 50);
    expect(first.nextOffset, 50);
    expect(first.indices, List.generate(50, (index) => index * 2));
    var second = await pager.load(readWindow: read, offset: 50);
    expect(second.files.length, 50);
    expect(second.offset, 50);
    expect(second.nextOffset, 100);
    expect(second.files.first.path, 'episode-50.mkv');
    expect(second.indices.first, 100);
    var last = await pager.load(readWindow: read, offset: 100);
    expect(last.files.length, 4);
    expect(last.indices, [200, 202, 204, 206]);
    expect(last.nextOffset, isNull);
    expect(last.files.any((file) => file.isPadding), isFalse);
  });

  test('跨多个引擎窗口建立索引后，刷新只读取当前页', () async {
    var files = _files(600);
    var pager = DownloadFilePager();
    var reads = <int>[];
    Future<BtTaskFilesResult> read(int offset, int limit) async {
      reads.add(offset);
      return _window(files, offset, limit);
    }

    await pager.load(readWindow: read, offset: 550);
    reads.clear();
    var page = await pager.load(readWindow: read, offset: 550);
    expect(reads, [1100]);
    expect(page.files.first.path, 'episode-550.mkv');
    expect(page.indices.first, 1100);
    expect(page.totalFiles, 600);
  });

  test('刷新时可跨越超过单次窗口的 padding 间隔', () async {
    var files = _files(60, paddingPerFile: 12);
    var pager = DownloadFilePager();
    Future<BtTaskFilesResult> read(int offset, int limit) async =>
        _window(files, offset, limit);
    await pager.load(readWindow: read);
    var page = await pager.load(readWindow: read);
    expect(page.files.length, 50);
    expect(page.indices.last, 49 * 13);
    expect(page.files.last.path, 'episode-49.mkv');
  });

  test('跳转越界时返回最后一页的真实文件', () async {
    var files = _files(104);
    var pager = DownloadFilePager();
    var page = await pager.load(
      readWindow: (offset, limit) async => _window(files, offset, limit),
      offset: 9999,
    );
    expect(page.offset, 100);
    expect(page.files.length, 4);
    expect(page.nextOffset, isNull);
  });

  test('元数据从空变为就绪时重新建立索引', () async {
    var files = <BtTaskFileDetail>[];
    var pager = DownloadFilePager();
    Future<BtTaskFilesResult> read(int offset, int limit) async =>
        _window(files, offset, limit);
    var empty = await pager.load(readWindow: read);
    expect(empty.files, isEmpty);
    expect(empty.totalFiles, 0);
    files = _files(104);
    var ready = await pager.load(readWindow: read);
    expect(ready.files.length, 50);
    expect(ready.totalFiles, 104);
  });

  test('拒绝没有前进的引擎分页，避免无限读取', () async {
    var files = _files(600);
    await expectLater(
      DownloadFilePager().load(
        readWindow: (offset, limit) async => BtTaskFilesResult(
          files: files.take(limit).toList(),
          truncated: true,
          totalFiles: files.length,
          totalContentFiles: 600,
          offset: offset,
          nextOffset: offset,
        ),
      ),
      throwsFormatException,
    );
  });

  test('批量优先级响应按原始索引应用到当前可见页', () async {
    var files = _files(104);
    var page = await DownloadFilePager().load(
      readWindow: (offset, limit) async => _window(files, offset, limit),
      offset: 50,
    );
    var priorities = List.filled(files.length, 4);
    priorities[100] = 0;
    priorities[198] = 7;
    var updated = page.withPriorities(priorities);
    expect(updated.files.first.isSkipped, isTrue);
    expect(updated.files.last.priority, 7);
    expect(updated.indices, page.indices);
    expect(updated.offset, 50);
    expect(page.files.first.priority, 4);
    expect(() => page.withPriorities([4]), throwsFormatException);
  });
}
