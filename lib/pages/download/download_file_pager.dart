// Dart imports:
import 'dart:math';

// Project imports:
import '../../core/services/bt_engine/protocol.dart';

typedef DownloadFileWindowReader =
    Future<BtTaskFilesResult> Function(int offset, int limit);

class DownloadFilePage {
  const DownloadFilePage({
    required this.files,
    required this.indices,
    required this.offset,
    required this.totalFiles,
  });

  final List<BtTaskFileDetail> files;
  final List<int> indices;
  final int offset;
  final int totalFiles;

  int get contentFileCount => totalFiles;
  bool get truncated => offset + files.length < totalFiles;
  int? get nextOffset => truncated ? offset + files.length : null;

  DownloadFilePage withPriorities(List<int> priorities) {
    if (indices.any((index) => index < 0 || index >= priorities.length)) {
      throw const FormatException('文件优先级响应缺少原始索引');
    }
    return DownloadFilePage(
      files: [
        for (var i = 0; i < files.length; i++)
          BtTaskFileDetail(
            path: files[i].path,
            size: files[i].size,
            completedBytes: files[i].completedBytes,
            priority: priorities[indices[i]],
            paddingFile: files[i].paddingFile,
          ),
      ],
      indices: indices,
      offset: offset,
      totalFiles: totalFiles,
    );
  }
}

/// UI 按真实文件分页；引擎窗口及文件选择继续使用包含 padding 的原始索引。
/// 文件结构就绪后缓存索引映射，刷新只读取当前页对应的原始窗口。
class DownloadFilePager {
  static const _windowSize = 500;
  List<int>? _indices;
  int? _rawFileCount;

  Future<DownloadFilePage> load({
    required DownloadFileWindowReader readWindow,
    int offset = 0,
    int pageSize = 50,
  }) async {
    if (offset < 0) throw ArgumentError.value(offset, 'offset');
    if (pageSize < 1) throw ArgumentError.value(pageSize, 'pageSize');
    var requested = offset ~/ pageSize * pageSize;
    var cached = _indices;
    var rawStart = cached != null && requested < cached.length
        ? cached[requested]
        : 0;
    var limit = cached != null && requested < cached.length
        ? min(
            _windowSize,
            cached[min(cached.length, requested + pageSize) - 1] - rawStart + 1,
          )
        : _windowSize;
    var first = await _read(readWindow, rawStart, limit);
    var loaded = <int, BtTaskFileDetail>{
      for (var i = 0; i < first.files.length; i++)
        first.offset + i: first.files[i],
    };
    if (cached == null ||
        _rawFileCount != first.totalFiles ||
        cached.length != first.totalContentFiles) {
      var indices = <int>[];
      var visibleStart = first.totalContentFiles == 0
          ? 0
          : min(
              requested,
              (first.totalContentFiles - 1) ~/ pageSize * pageSize,
            );
      var cursor = 0;
      while (true) {
        var page = cursor == first.offset
            ? first
            : await _read(readWindow, cursor, _windowSize);
        _checkTotals(page, first);
        for (var i = 0; i < page.files.length; i++) {
          var file = page.files[i];
          if (file.isPadding) continue;
          var index = page.offset + i;
          if (indices.length >= visibleStart &&
              indices.length < visibleStart + pageSize) {
            loaded[index] = file;
          }
          indices.add(index);
        }
        if (!page.truncated) break;
        cursor = page.nextOffset!;
      }
      if (indices.length != first.totalContentFiles) {
        throw const FormatException('真实文件数量与引擎统计不一致');
      }
      _indices = cached = indices;
      _rawFileCount = first.totalFiles;
    }
    var visibleOffset = cached.isEmpty
        ? 0
        : min(requested, (cached.length - 1) ~/ pageSize * pageSize);
    var selected = cached.sublist(
      visibleOffset,
      min(cached.length, visibleOffset + pageSize),
    );
    var wanted = selected.toSet();
    for (var index in selected) {
      if (loaded.containsKey(index)) continue;
      var page = await _read(
        readWindow,
        index,
        min(_windowSize, selected.last - index + 1),
      );
      _checkTotals(page, first);
      for (var i = 0; i < page.files.length; i++) {
        var rawIndex = page.offset + i;
        if (wanted.contains(rawIndex)) loaded[rawIndex] = page.files[i];
      }
    }
    var files = [for (var index in selected) loaded[index]!];
    if (files.any((file) => file.isPadding)) {
      throw const FormatException('文件索引映射已失效');
    }
    return DownloadFilePage(
      files: files,
      indices: selected,
      offset: visibleOffset,
      totalFiles: cached.length,
    );
  }

  static Future<BtTaskFilesResult> _read(
    DownloadFileWindowReader reader,
    int offset,
    int limit,
  ) async {
    var page = await reader(offset, limit);
    if (page.offset != offset ||
        page.files.length > limit ||
        (offset < page.totalFiles && page.files.isEmpty) ||
        (page.truncated && page.nextOffset != offset + page.files.length)) {
      throw const FormatException('引擎文件分页窗口无效');
    }
    return page;
  }

  static void _checkTotals(BtTaskFilesResult page, BtTaskFilesResult first) {
    if (page.totalFiles != first.totalFiles ||
        page.totalContentFiles != first.totalContentFiles) {
      throw const FormatException('读取期间文件结构发生变化，请刷新');
    }
  }
}
