// Package imports:
import 'package:fluent_ui/fluent_ui.dart';

// Project imports:
import '../../components/app/app_infobar.dart';

/// 页面controller
class BtcPageController extends ChangeNotifier {
  /// 总页数
  late int total;

  /// 当前页
  late int cur;

  /// 展示数量
  /// 默认为5，包括起始页、结束页、当前页、前一页、后一页
  /// 如果总数小于5，则展示全部
  final int visible = 5;

  /// 页面改变回调
  Future<void> Function(int) onChanged;

  /// 构造函数
  BtcPageController({
    required this.total,
    required this.cur,
    required this.onChanged,
  });

  /// 默认构造函数
  static BtcPageController defaultInit() {
    return BtcPageController(total: 0, cur: 0, onChanged: (page) async {});
  }

  /// 总页数
  int get totalPage => (total / visible).ceil();

  /// 获取展示的页码
  /// 当总页码小于展示数量时，展示全部
  /// 当总页码大于展示数量时，展示当前页码附近的页码
  /// 例：当前页1，总页码10，展示 1 2 3 -1 9 10
  /// 例：当前页5，总页码10，展示 1 -1 4 5 6 -1 10
  /// 例：当前页10，总页码10，展示 1 2 -1 8 9 10
  /// 中间空缺用 -1 表示
  List<int> get visiblePages {
    if (totalPage <= visible) {
      return List.generate(totalPage, (index) => index + 1);
    }
    if (cur < 3) {
      return [1, 2, 3, -1, totalPage - 1, totalPage];
    }
    if (cur > totalPage - 2) {
      return [1, 2, -1, totalPage - 2, totalPage - 1, totalPage];
    }
    if (cur == 3) {
      return [1, 2, 3, 4, -1, totalPage];
    }
    if (cur == totalPage - 2) {
      return [1, -1, totalPage - 3, totalPage - 2, totalPage - 1, totalPage];
    }
    return [1, -1, cur - 1, cur, cur + 1, -1, totalPage];
  }

  /// 重置数据
  void reset({required int total, required int cur}) {
    this.total = total;
    this.cur = cur;
    notifyListeners();
  }

  /// 跳转到指定页
  Future<void> jump(int page) async {
    if (page >= 1 && page <= totalPage) {
      await onChanged(page);
      cur = page;
      notifyListeners();
    }
  }
}

/// 页面组件
class PageWidget extends StatefulWidget {
  /// 控制器
  final BtcPageController controller;

  /// 构造
  const PageWidget(this.controller, {super.key});

  /// 状态
  @override
  State<PageWidget> createState() => _PageWidgetState();
}

/// 页面组件状态
class _PageWidgetState extends State<PageWidget> {
  /// 数据
  BtcPageController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    controller.addListener(() {
      setState(() {});
    });
  }

  /// 获取背景色
  Color getBackgroundColor(int index) {
    var base = FluentTheme.of(context).accentColor;
    if (index == controller.cur) {
      return base;
    }
    return Colors.transparent;
  }

  /// 构建页码
  List<Widget> buildPages() {
    var pages = controller.visiblePages;
    var result = <Widget>[];
    result.add(
      PageItemBtn(
        icon: FluentIcons.chevron_left,
        text: '上一页',
        onPressed: () async {
          if (controller.cur > 1) {
            await controller.jump(controller.cur - 1);
          } else {
            if (mounted) await BtInfobar.warn(context, '已经是第一页');
          }
        },
      ),
    );
    result.add(const SizedBox(width: 4));
    for (var page in pages) {
      if (page == -1) {
        result.add(const PageItemText('...'));
      } else {
        result.add(PageItemPage(
          page: page,
          cur: controller.cur,
          onPressed: controller.jump,
        ));
      }
      result.add(const SizedBox(width: 4));
    }
    result.add(
      PageItemBtn(
        icon: FluentIcons.chevron_right,
        text: '下一页',
        onPressed: () async {
          if (controller.cur < controller.totalPage) {
            await controller.jump(controller.cur + 1);
          } else {
            if (mounted) await BtInfobar.warn(context, '已经是最后一页');
          }
        },
      ),
    );
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.center,
      children: buildPages(),
    );
  }
}

/// 单项页面-跳转
class PageItemBtn extends StatelessWidget {
  /// icon
  final IconData icon;

  /// 文本
  final String text;

  /// 点击事件
  final Future<void> Function() onPressed;

  /// 构造
  const PageItemBtn({
    required this.icon,
    required this.text,
    required this.onPressed,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: text,
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon),
      ),
    );
  }
}

/// 单项页面-页码
class PageItemPage extends StatelessWidget {
  /// 页码
  final int page;

  /// 当前页
  final int cur;

  /// 点击事件
  final Future<void> Function(int) onPressed;

  /// 构造
  const PageItemPage({
    required this.page,
    required this.cur,
    required this.onPressed,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Button(
      onPressed: () async {
        if (cur == page) {
          await BtInfobar.warn(context, '已经是第$page页');
          return;
        }
        await onPressed(page);
      },
      style: ButtonStyle(
        backgroundColor: ButtonState.all(cur == page
            ? FluentTheme.of(context).accentColor
            : Colors.transparent),
      ),
      child: Text('$page'),
    );
  }
}

/// 单项页面-文本
class PageItemText extends StatelessWidget {
  /// 文本
  final String text;

  /// 构造
  const PageItemText(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(text);
  }
}
