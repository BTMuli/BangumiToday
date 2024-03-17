import 'package:fluent_ui/fluent_ui.dart';
import 'package:go_router/go_router.dart';

/// 番剧详情
class BangumiDetail extends StatefulWidget {
  /// 番剧 id
  final String id;

  /// 构造函数
  const BangumiDetail({super.key, required this.id});

  @override
  State<BangumiDetail> createState() => _BangumiDetailState();
}

/// 番剧详情状态
class _BangumiDetailState extends State<BangumiDetail> {
  @override
  Widget build(BuildContext context) {
    return ScaffoldPage(
      header: PageHeader(
        leading: IconButton(
          icon: const Icon(FluentIcons.back),
          onPressed: () {
            if (!GoRouter.of(context).canPop()) {
              GoRouter.of(context).go('/');
              return;
            }
            GoRouter.of(context).pop();
          },
        ),
        title: Text('番剧详情'),
      ),
      content: Center(
        child: Text('Bangumi Detail'),
      ),
    );
  }
}
