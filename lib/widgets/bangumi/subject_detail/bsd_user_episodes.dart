// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

// Project imports:
import '../../../models/bangumi/bangumi_enum.dart';
import '../../../models/bangumi/bangumi_model.dart';
import '../../../pages/bangumi/bangumi_detail.dart';
import '../../../request/bangumi/bangumi_api.dart';
import '../../../ui/bt_infobar.dart';
import 'bsd_episode.dart';

/// SubjectDetail页面的章节模块，负责显示/操作章节信息
class BsdUserEpisodes extends StatefulWidget {
  /// subjectInfo
  final BangumiSubject subject;

  /// user
  final BangumiUser? user;

  /// provider
  final BangumiDetailProvider provider;

  /// 构造函数
  const BsdUserEpisodes(this.subject, this.user, this.provider, {super.key});

  @override
  State<BsdUserEpisodes> createState() => _BsdUserEpisodesState();
}

// todo，当条目章节数量过多时，需要分页加载，比如名侦探柯南(id:899)
class _BsdUserEpisodesState extends State<BsdUserEpisodes>
    with AutomaticKeepAliveClientMixin {
  /// subject_id
  int get subjectId => widget.subject.id;

  /// 用户
  BangumiUser? get user => widget.user;

  /// 是否收藏
  late bool isCollection;

  /// 请求客户端
  final BtrBangumiApi api = BtrBangumiApi();

  /// 章节信息
  List<BangumiEpisode> episodes = [];

  /// 用户章节信息
  List<BangumiUserEpisodeCollection> userEpisodes = [];

  /// offset
  int offset = 0;

  @override
  bool get wantKeepAlive => true;

  /// 初始化
  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      if (widget.subject.type == BangumiSubjectType.anime) {
        await check();
        await load();
      }
    });
    addProviderListener();
  }

  /// 添加provider监听
  void addProviderListener() {
    widget.provider.addListener((val) async {
      if (!val) return;
      if (user == null) return;
      if (isCollection) return;
      if (widget.subject.type == BangumiSubjectType.anime) {
        offset = 0;
        episodes.clear();
        userEpisodes.clear();
        if (mounted) setState(() {});
        await check();
        await load();
        if (mounted) await BtInfobar.success(context, '成功更新章节信息');
      }
    });
  }

  /// 检测是否收藏
  Future<void> check() async {
    if (user == null) return;
    var resp = await api.getCollectionSubject(user!.id.toString(), subjectId);
    isCollection = resp.code != 404;
    setState(() {});
  }

  /// 加载更多
  Future<void> load() async {
    var ep1Resp = await api.getEpisodeList(
      subjectId,
      offset: offset,
      limit: 30,
    );
    var pageLen = 0;
    if (ep1Resp.code == 0) {
      var page = ep1Resp.data as BangumiPageT<BangumiEpisode>;
      episodes.addAll(page.data);
      pageLen = page.data.length;
    }
    if (user != null && isCollection) {
      var ep2Resp = await api.getCollectionEpisodes(
        subjectId,
        offset: offset,
        limit: 30,
      );
      if (ep2Resp.code == 0) {
        var page = ep2Resp.data as BangumiPageT<BangumiUserEpisodeCollection>;
        userEpisodes.addAll(page.data);
      }
    }
    offset += pageLen;
    if (mounted) setState(() {});
  }

  /// buildEpHint 用于表示章节的提示信息
  Widget buildEpHint(BangumiEpType type) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4.sp),
        color: FluentTheme.of(context).accentColor,
      ),
      child: Text(
        '${type.label} →',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }

  /// buildList
  List<Widget> buildList() {
    var res = <Widget>[];
    episodes.sort(
      (a, b) => a.type == b.type
          ? a.sort.compareTo(b.sort)
          : b.type.value.compareTo(a.type.value),
    );
    var curType = episodes[0].type;
    if (curType != BangumiEpType.main) {
      res.add(buildEpHint(curType));
    }
    for (var i = 0; i < episodes.length; i++) {
      if (curType != episodes[i].type) {
        curType = episodes[i].type;
        res.add(buildEpHint(curType));
      }
      // 在userEpisodes中找到对应的章节信息
      var find = userEpisodes.indexWhere(
        (element) => element.episode.id == episodes[i].id,
      );
      if (find != -1) {
        res.add(BsdEpisode(episodes[i], user: userEpisodes[find]));
      } else {
        res.add(BsdEpisode(episodes[i]));
      }
    }
    if (episodes.length < widget.subject.totalEpisodes) {
      res.add(
        Button(
          onPressed: () async {
            await load();
          },
          child: const Text('加载更多'),
        ),
      );
    }
    return res;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (episodes.isEmpty) return const SizedBox.shrink();
    return Wrap(spacing: 8.w, runSpacing: 12.h, children: buildList());
  }
}
