import 'package:go_router/go_router.dart';

import '../components/app/app_nav.dart';
import '../pages/bangumi_detail.dart';
import 'switch_animate.dart';

/// 路由
final router = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) {
        return AppNav();
      },
      pageBuilder: (context, state) {
        return centerFloatAnimate(context, state, AppNav());
      },
    ),
    // 含参路由
    GoRoute(
      path: '/bangumi/:id',
      builder: (context, state) {
        final id = state.pathParameters['id'];
        if (id == null) return AppNav();
        return BangumiDetail(id: id);
      },
      pageBuilder: (context, state) {
        var child;
        final id = state.pathParameters['id'];
        if (id == null) {
          child = AppNav();
        } else {
          child = BangumiDetail(id: id);
        }
        return slideUpAnimate(context, state, child);
      },
    ),
  ],
);
