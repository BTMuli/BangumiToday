import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../database/bangumi/bangumi_user.dart';
import '../../../models/bangumi/bangumi_model.dart';
import '../../../request/bangumi/bangumi_api.dart';
import 'bsd_episode.dart';

/// SubjectDetail页面的用于模块
class BsdUser extends ConsumerStatefulWidget {
  /// subjectInfo
  final BangumiSubject subject;

  /// 构造函数
  const BsdUser(this.subject, {super.key});

  @override
  ConsumerState<BsdUser> createState() => _BsdUserState();
}

class _BsdUserState extends ConsumerState<BsdUser>
    with AutomaticKeepAliveClientMixin {
  /// subject_id
  int get subjectId => widget.subject.id;

  /// 数据库
  final BtsBangumiUser sqlite = BtsBangumiUser();

  /// 请求客户端
  final BtrBangumiApi api = BtrBangumiApi();

  /// user
  BangumiUser? user;

  /// accessToken
  String? accessToken;

  /// 章节信息
  List<BangumiEpisode> episodes = [];

  /// 用户章节信息
  List<BangumiUserEpisodeCollection> userEpisodes = [];

  /// offset
  int offset = 0;

  /// todo 后续差不多了改成true
  @override
  bool get wantKeepAlive => false;

  /// 初始化
  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await init();
    });
  }

  /// 初始化
  Future<void> init() async {
    user = await sqlite.readUser();
    accessToken = await sqlite.readAccessToken();
    setState(() {});
    await loadMore();
  }

  /// 加载更多
  Future<void> loadMore() async {
    var ep1Resp = await api.getEpisodeList(
      subjectId,
      offset: offset,
      limit: 30,
    );
    var ep2Resp = await api.getCollectionEpisodes(
      subjectId,
      offset: offset,
      limit: 30,
    );
    if (ep1Resp.code == 0) {
      var page = ep1Resp.data as BangumiPageT<BangumiEpisode>;
      episodes.addAll(page.data);
    }
    if (ep2Resp.code == 0) {
      var page = ep2Resp.data as BangumiPageT<BangumiUserEpisodeCollection>;
      userEpisodes.addAll(page.data);
    }
    offset += 30;
    setState(() {});
  }

  /// buildList
  List<Widget> buildList() {
    var res = <Widget>[];
    for (var i = 0; i < episodes.length; i++) {
      res.add(BsdEpisode(episodes[i], user: userEpisodes[i]));
    }
    if (episodes.length < widget.subject.totalEpisodes) {
      res.add(
        Padding(
          padding: EdgeInsets.only(top: 12.h),
          child: Center(
            child: Button(
              onPressed: () async {
                await loadMore();
              },
              child: Text('加载更多'),
            ),
          ),
        ),
      );
    }
    return res;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (user == null) {
      return Container();
    }

    /// todo 添加整个subject的收藏信息
    return Wrap(spacing: 8.w, runSpacing: 12.h, children: buildList());
  }
}
