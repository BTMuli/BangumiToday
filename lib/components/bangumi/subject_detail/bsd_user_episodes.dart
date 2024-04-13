import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../database/bangumi/bangumi_user.dart';
import '../../../models/bangumi/bangumi_model.dart';
import '../../../request/bangumi/bangumi_api.dart';
import 'bsd_episode.dart';

/// SubjectDetail页面的章节模块，负责显示/操作章节信息
class BsdUserEpisodes extends StatefulWidget {
  /// subjectInfo
  final BangumiSubject subject;

  /// 用户
  final BangumiUser? user;

  /// 构造函数
  const BsdUserEpisodes(this.subject, {super.key, this.user});

  @override
  State<BsdUserEpisodes> createState() => _BsdUserEpisodesState();
}

class _BsdUserEpisodesState extends State<BsdUserEpisodes>
    with AutomaticKeepAliveClientMixin {
  /// subject_id
  int get subjectId => widget.subject.id;

  /// 用户
  BangumiUser? get user => widget.user;

  /// 数据库
  final BtsBangumiUser sqlite = BtsBangumiUser();

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
      await load();
    });
  }

  /// 加载更多
  Future<void> load() async {
    assert(user != null);
    var ep1Resp = await api.getEpisodeList(
      subjectId,
      offset: offset,
      limit: 30,
    );
    if (ep1Resp.code == 0) {
      var page = ep1Resp.data as BangumiPageT<BangumiEpisode>;
      episodes.addAll(page.data);
    }
    if (user != null) {
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
    offset += 30;
    setState(() {});
  }

  /// buildList
  List<Widget> buildList() {
    var res = <Widget>[];
    episodes.sort((a, b) => a.sort.compareTo(b.sort));
    userEpisodes.sort((a, b) => a.episode.sort.compareTo(b.episode.sort));
    for (var i = 0; i < episodes.length; i++) {
      if (i >= userEpisodes.length) {
        res.add(BsdEpisode(episodes[i]));
      } else {
        res.add(BsdEpisode(episodes[i], user: userEpisodes[i]));
      }
    }
    if (episodes.length < widget.subject.totalEpisodes) {
      res.add(
        Button(
          onPressed: () async {
            await load();
          },
          child: Text('加载更多'),
        ),
      );
    }
    return res;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (episodes.isEmpty) {
      return Container();
    }
    return Wrap(spacing: 8.w, runSpacing: 12.h, children: buildList());
  }
}
