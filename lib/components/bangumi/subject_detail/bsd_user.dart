import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../database/bangumi/bangumi_user.dart';
import '../../../models/app/response.dart';
import '../../../models/bangumi/bangumi_enum.dart';
import '../../../models/bangumi/bangumi_model.dart';
import '../../../request/bangumi/bangumi_api.dart';
import '../../app/app_dialog_resp.dart';
import 'bsd_episode.dart';

/// SubjectDetail页面的用于模块
class BsdUser extends ConsumerStatefulWidget {
  /// subject id
  final int id;

  /// 构造函数
  const BsdUser(this.id, {super.key});

  @override
  ConsumerState<BsdUser> createState() => _BsdUserState();
}

class _BsdUserState extends ConsumerState<BsdUser>
    with AutomaticKeepAliveClientMixin {
  /// subject_id
  int get subjectId => widget.id;

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
    var ep1Resp = await api.getEpisodeList(subjectId);
    var ep2Resp = await api.getCollectionEpisodes(subjectId);
    if (ep1Resp.code == 0) {
      var page = ep1Resp.data as BangumiPageT<BangumiEpisode>;
      episodes = page.data;
    }
    if (ep2Resp.code == 0) {
      var page = ep2Resp.data as BangumiPageT<BangumiUserEpisodeCollection>;
      userEpisodes = page.data;
    }
    setState(() {});
  }

  /// 构建章节
  Widget buildEpisode(BuildContext context, int index) {
    var baseColor = FluentTheme.of(context).accentColor;
    var episode = episodes[index];
    var userEpisode = userEpisodes[index];
    Color bgColor;
    var userType = userEpisode.type;
    switch (userType) {
      case BangumiEpisodeCollectionType.none:
        bgColor = Colors.transparent;
        break;
      case BangumiEpisodeCollectionType.wish:
        bgColor = baseColor.light;
        break;
      case BangumiEpisodeCollectionType.done:
        bgColor = baseColor;
        break;
      case BangumiEpisodeCollectionType.dropped:
        bgColor = baseColor.dark;
        break;
    }
    var sort = episode.sort.toStringAsFixed(0);
    if (episode.sort.toInt() != episode.sort) {
      sort = episode.sort.toStringAsFixed(1);
    }
    return Button(
      style: ButtonStyle(
        backgroundColor: ButtonState.all(bgColor),
      ),
      child: Tooltip(
        message: episode.nameCn,
        child: Text('$sort'),
      ),
      onPressed: () async {
        if (index < userEpisodes.length) {
          showRespErr(
            BTResponse.success(data: userEpisodes[index]),
            context,
            title: '章节信息',
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (user == null) {
      return Container();
    }

    /// todo 添加整个subject的收藏信息
    return Wrap(
      spacing: 8.w,
      children: List.generate(
        episodes.length,
        (index) => BsdEpisode(episodes[index], user: userEpisodes[index]),
      ),
    );
  }
}
