// Package imports:
import 'package:go_router/go_router.dart';

// Project imports:
import 'components/app/app_nav.dart';
import 'pages/play/play_page.dart';

/// 路由
final router = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      name: 'home',
      builder: (context, state) => const AppNav(),
    ),
    GoRoute(
      path: '/play/:subject',
      name: 'play',
      builder: (context, state) {
        var subject = state.pathParameters['subject'];
        return PlayPage(subject: int.parse(subject!));
      },
    ),
  ],
);
