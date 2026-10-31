// Dart imports:
import 'dart:async';
import 'dart:io';

// Package imports:
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:path/path.dart' as path;

// Project imports:
import 'package:bangumi_today/controller/download_subject_search_controller.dart';
import 'package:bangumi_today/core/services/bt_engine/protocol.dart';
import 'package:bangumi_today/core/utils/download_subject.dart';
import 'package:bangumi_today/database/app/download_subjects.dart';
import 'package:bangumi_today/domain/repositories/bangumi_repository.dart';
import 'package:bangumi_today/models/app/response.dart';
import 'package:bangumi_today/models/bangumi/bangumi_enum.dart';
import 'package:bangumi_today/models/bangumi/bangumi_model.dart';
import 'package:bangumi_today/models/bangumi/request_subject.dart';
import 'package:bangumi_today/models/database/app_bmf_model.dart';
import 'package:bangumi_today/pages/download/download_task_helpers.dart';

typedef _SearchResponse = BTResponse<BangumiPageT<BangumiSubjectSearchData>>;

class _Subject extends Fake implements BangumiSubjectSearchData {
  _Subject(this.id);

  @override
  int id;
}

class _SearchRequest {
  _SearchRequest(this.keyword, this.offset, this.limit);

  final String keyword;
  final int offset;
  final int limit;
  final reply = Completer<_SearchResponse>();

  void complete(List<int> ids, {int? total}) => reply.complete(
    BTResponse.success(
      data: BangumiPageT(
        total: total ?? ids.length,
        limit: limit,
        offset: offset,
        data: ids.map(_Subject.new).toList(),
      ),
    ),
  );
}

class _Repository extends Fake implements BTBangumiRepository {
  final requests = <_SearchRequest>[];

  @override
  Future<dynamic> searchSubjects(
    String keyword, {
    String sort = 'match',
    int offset = 0,
    int limit = 10,
    List<BangumiSubjectType> type = const [BangumiSubjectType.anime],
    List<String>? tag,
    List<String>? metaTag,
    List<String>? airdate,
    List<String>? rating,
    List<String>? rank,
    bool? nsfw,
  }) {
    var request = _SearchRequest(keyword, offset, limit);
    requests.add(request);
    return request.reply.future;
  }
}

void main() {
  group('BMF 下载目录候选', () {
    var directory = path.join(Directory.current.path, 'library', 'season-one');
    var equivalent = path.join(directory, '..', 'season-one', '.');

    test('规范化后精确匹配目录，忽略空目录、无效 ID 和子目录', () {
      var directories = [
        (subject: 50814, directory: equivalent),
        (subject: 50814, directory: directory),
        (subject: 330057, directory: directory),
        (subject: 570448, directory: path.join(directory, 'extra')),
        (subject: 42, directory: ''),
        (subject: 43, directory: null),
        (subject: 0, directory: directory),
      ];
      expect(
        findDownloadDirectorySubjects(
          savePath: directory,
          directories: directories,
        ),
        {50814, 330057},
      );
      expect(
        findDownloadDirectorySubjects(savePath: '', directories: directories),
        isEmpty,
      );
      expect(
        findDownloadSubject(savePath: directory, directories: directories),
        isNull,
      );
      expect(
        findDownloadSubject(
          savePath: directory,
          linkedSubject: 570448,
          directories: directories,
        ),
        570448,
      );
      expect(
        findDownloadSubject(
          savePath: directory,
          directories: [(subject: 50814, directory: equivalent)],
        ),
        50814,
      );
    });

    test('目录匹配置顶并带有 BMF 标记，保留搜索详情且不重复候选', () {
      var matched = AppBmfModel(subject: 50814, download: equivalent);
      var searched = [_Subject(570448), _Subject(330057), _Subject(50814)];
      var candidates = prioritizeDownloadSubjectCandidates(
        savePath: directory,
        bmfs: [
          matched,
          AppBmfModel(subject: 330057, download: path.join(directory, 'other')),
        ],
        results: searched,
      );
      expect(candidates.map((candidate) => candidate.id), [
        50814,
        570448,
        330057,
      ]);
      expect(candidates.first.directoryMatch, same(matched));
      expect(candidates.first.searchResult, same(searched.last));
      expect(candidates.skip(1).every((c) => c.directoryMatch == null), isTrue);
    });

    test('搜索没有结果时仍列出所有同目录 BMF 条目，并按条目 ID 去重', () {
      var candidates = prioritizeDownloadSubjectCandidates(
        savePath: directory,
        bmfs: [
          AppBmfModel(subject: 50814, title: '第一季', download: equivalent),
          AppBmfModel(subject: 330057, title: '第二季', download: directory),
          AppBmfModel(subject: 50814, title: '第一季', download: directory),
        ],
        results: [],
      );
      expect(candidates.map((candidate) => candidate.id), [50814, 330057]);
      expect(candidates.every((c) => c.directoryMatch != null), isTrue);
      expect(candidates.every((c) => c.searchResult == null), isTrue);
    });
  });

  test('资源标题只生成可编辑搜索词，去掉字幕组、技术标记和季度后缀', () {
    expect(
      downloadSubjectSearchKeyword(
        '[7³ACG] 打工吧！魔王大人/Hataraku Maousama! S01 | '
        '01-13 [简繁字幕] BDrip 1080p AV1 OPUS 2.0',
      ),
      '打工吧！魔王大人',
    );
    expect(
      downloadSubjectSearchKeyword(
        '[动漫国字幕组&LoliHouse] 打工吧!! 魔王大人 / '
        'Hataraku Maou-sama S2 [01-12 修正合集]'
        '[WebRip 1080p HEVC-10bit AAC][简繁外挂字幕][Fin]',
      ),
      '打工吧!! 魔王大人',
    );
    expect(
      downloadSubjectSearchKeyword('[Group] Example Anime S02 - 12 [1080p]'),
      'Example Anime',
    );
    expect(downloadSubjectSearchKeyword('  普通番剧名  '), '普通番剧名');
    expect(downloadSubjectSearchKeyword('[只有括号标题]'), '[只有括号标题]');
    expect(downloadSubjectSearchKeyword(''), isEmpty);
  });

  group('条目候选搜索', () {
    late _Repository repository;
    late DownloadSubjectSearchController controller;

    setUp(() {
      repository = _Repository();
      controller = DownloadSubjectSearchController(repository);
    });

    tearDown(() => controller.dispose());

    test('输入改变立即作废旧请求，等待下一次搜索期间不显示旧结果', () async {
      controller.changeQuery('旧名称');
      var old = controller.search();
      controller.changeQuery(' 新名称 ');
      repository.requests.single.complete([570448]);
      await old;
      expect(controller.query, '新名称');
      expect(controller.results, isEmpty);
      expect(controller.searched, isFalse);
      expect(controller.loading, isFalse);

      var current = controller.search();
      expect(repository.requests.last.keyword, '新名称');
      repository.requests.last.complete([50814, 330057]);
      await current;
      expect(controller.results.map((subject) => subject.id), [50814, 330057]);
      expect(controller.searched, isTrue);
    });

    test('迟到的失败不能覆盖新搜索结果或错误状态', () async {
      controller.changeQuery('旧名称');
      var old = controller.search();
      controller.changeQuery('魔王大人');
      var current = controller.search();
      repository.requests.last.complete([50814]);
      await current;
      repository.requests.first.reply.completeError(StateError('旧请求失败'));
      await old;
      expect(controller.results.single.id, 50814);
      expect(controller.error, isNull);
      expect(controller.loading, isFalse);
    });

    test('加载更多失败保留候选，重试相同 offset 并按总数结束', () async {
      controller.changeQuery('魔王大人');
      var first = controller.search();
      repository.requests.last.complete([50814, 330057], total: 3);
      await first;
      expect(controller.hasMore, isTrue);
      var more = controller.search(more: true);
      expect(repository.requests.last.offset, 2);
      repository.requests.last.reply.complete(
        BTResponse.error(code: 503, message: 'offline', data: null),
      );
      await more;
      expect(controller.results.length, 2);
      expect(controller.error, isNotNull);
      var retry = controller.search(more: true);
      expect(repository.requests.last.offset, 2);
      repository.requests.last.complete([400602], total: 3);
      await retry;
      expect(controller.results.map((subject) => subject.id), [
        50814,
        330057,
        400602,
      ]);
      expect(controller.hasMore, isFalse);
      expect(controller.error, isNull);
      await controller.search(more: true);
      expect(repository.requests.length, 3);
    });

    test('空查询不发送请求，清空输入清除已有候选', () async {
      await controller.search();
      expect(repository.requests, isEmpty);
      controller.changeQuery('番剧');
      var result = controller.search();
      repository.requests.single.complete([50814]);
      await result;
      controller.changeQuery(' ');
      await controller.search();
      expect(repository.requests.length, 1);
      expect(controller.results, isEmpty);
      expect(controller.hasMore, isFalse);
    });
  });

  test('已有任务的错误关联可单独覆盖、实时重分组并在重新打开后保留', () async {
    var tempRoot = Directory(
      path.join(Directory.current.path, 'temp', 'download-subject-repair'),
    );
    await tempRoot.create(recursive: true);
    var hiveDirectory = await tempRoot.createTemp('hive-');
    Hive.init(hiveDirectory.path);
    addTearDown(() async {
      await Hive.close();
      if (!path.isWithin(tempRoot.absolute.path, hiveDirectory.absolute.path)) {
        throw StateError('test data must stay inside its temporary directory');
      }
      await hiveDirectory.delete(recursive: true);
      if (await tempRoot.list().isEmpty) await tempRoot.delete();
    });
    var storage = DownloadSubjectsStorage();
    await storage.write('season-one', 570448);
    await storage.write('season-two', 570448);
    var changes = StreamIterator(storage.watch('season-one'));
    addTearDown(changes.cancel);
    expect(await changes.moveNext(), isTrue);
    expect(changes.current, 570448);

    await storage.write('season-one', 50814);
    expect(await changes.moveNext(), isTrue);
    expect(changes.current, 50814);
    expect(await storage.read('season-two'), 570448);
    await storage.write('season-two', 330057);

    var tasks = [
      for (var id in ['season-one', 'season-two'])
        BtTaskSnapshot.fromJson({
          'id': id,
          'state': 'completed',
          'sourceKind': 'torrent',
          'manual': false,
          'savePath': r'C:\Downloads',
          'downloadMilliseconds': 0,
        }),
    ];
    var groups = groupDownloadTasks(tasks, {
      for (var task in tasks) task.id: await storage.read(task.id),
    });
    expect(groups.map((group) => group.subjectId), [50814, 330057]);
    expect(groups.map((group) => group.tasks.single.id), [
      'season-one',
      'season-two',
    ]);

    await changes.cancel();
    await Hive.close();
    var reopened = DownloadSubjectsStorage();
    expect(await reopened.read('season-one'), 50814);
    expect(await reopened.read('season-two'), 330057);
  });
}
