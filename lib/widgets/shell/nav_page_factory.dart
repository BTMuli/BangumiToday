// Package imports:
import 'package:fluent_ui/fluent_ui.dart';

// Project imports:
import '../../models/hive/nav_model.dart';
import '../../pages/subject_detail/subject_detail_page.dart';
import '../../pages/subject_search/subject_search_page.dart';
import 'nav_item_icon.dart';

/// 动态导航页的关闭回调集合。
class NavPageCloseActions {
  const NavPageCloseActions({
    required this.onClose,
    required this.onCloseOthers,
    required this.onCloseAll,
  });

  final VoidCallback onClose;
  final VoidCallback onCloseOthers;
  final VoidCallback onCloseAll;
}

/// 由路由描述构建侧边栏 [PaneItem]（含图标、关闭控件与占位 body）。
///
/// 实际内容栈由 [buildNavPageBody] 提供；此处 body 仅满足 Fluent
/// [PaneItem] 非空约束。
PaneItem buildNavPaneItem(
  NavRouteDescriptor route, {
  required NavPageCloseActions actions,
  Widget? appBody,
}) {
  var subjectId = route.subjectId;
  var identity = subjectId != null && subjectId > 0
      ? '${route.title} #$subjectId'
      : route.title;
  return PaneItem(
    icon: _paneIcon(route, actions),
    title: Text(route.title),
    tooltip: identity,
    semanticLabel: identity,
    body: buildNavPageBody(route, appBody: appBody) ?? const SizedBox.shrink(),
    trailing: Tooltip(
      message: '关闭「$identity」',
      child: IconButton(
        icon: Icon(
          FluentIcons.clear,
          semanticLabel: '关闭「$identity」',
        ),
        onPressed: actions.onClose,
      ),
    ),
  );
}

/// 由路由描述构建页面 body；app 类动态页使用 [appBody] 缓存。
Widget? buildNavPageBody(NavRouteDescriptor route, {Widget? appBody}) {
  if (route.type == BtmAppNavItemType.subject) {
    var id = route.subjectId;
    if (id == null || id <= 0) return null;
    var param = route.param ?? 'subjectDetail_$id';
    return SubjectDetailPage(key: ValueKey(param), id: id.toString());
  }
  if (appBody != null) return appBody;
  if (route.title == SubjectSearchPage.title) {
    return const SubjectSearchPage();
  }
  return null;
}

Widget _paneIcon(NavRouteDescriptor route, NavPageCloseActions actions) {
  if (route.type == BtmAppNavItemType.subject) {
    return NavItemIcon(
      title: route.title,
      subjectId: route.subjectId,
      onClose: actions.onClose,
      onCloseOthers: actions.onCloseOthers,
      onCloseAll: actions.onCloseAll,
    );
  }
  if (route.title == SubjectSearchPage.title) {
    return const Icon(FluentIcons.search);
  }
  return const Icon(FluentIcons.page);
}
