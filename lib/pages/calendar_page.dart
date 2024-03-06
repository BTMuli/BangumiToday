import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../components/nav_calendar/calendar_page_age.dart';
import '../components/nav_calendar/calendar_page_bangumi.dart';
import '../store/app_store.dart';

/// 今日放送
class CalendarPage extends ConsumerWidget {
  /// 构造函数
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final source = ref.watch(appStoreProvider).source;
    if (source == 'agefans') {
      return CalendarPageAge();
    }
    return CalendarPageBangumi();
  }
}
