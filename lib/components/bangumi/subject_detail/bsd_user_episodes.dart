import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../database/bangumi/bangumi_user.dart';
import '../../../models/bangumi/bangumi_enum.dart';
import '../../../models/bangumi/bangumi_enum_extension.dart';
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

// todo，当条目章节数量过多时，需要分页加载，比如名侦探柯南(id:899)
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
      if (widget.subject.type == BangumiSubjectType.anime) {
        await load();
      }
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
    if (context.mounted) {
      setState(() {});
    }
  }

  /// buildEpHint 用于表示章节的提示信息
  Widget buildEpHint(BangumiEpType type) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        color: FluentTheme.of(context).accentColor,
      ),
      child: Text(
        '${type.label} →',
        style: TextStyle(fontWeight: FontWeight.bold),
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
    userEpisodes.sort(
      (a, b) => a.episode.type == b.episode.type
          ? a.episode.sort.compareTo(b.episode.sort)
          : a.episode.type.value.compareTo(b.episode.type.value),
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
