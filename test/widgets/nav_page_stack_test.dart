// Flutter imports:
import 'package:flutter/widgets.dart';

// Package imports:
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:bangumi_today/widgets/app/nav_page_stack.dart';

class _Probe extends StatefulWidget {
  const _Probe({required this.label, required this.loads});

  final String label;
  final Map<String, int> loads;

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  @override
  void initState() {
    super.initState();
    widget.loads[widget.label] = (widget.loads[widget.label] ?? 0) + 1;
  }

  @override
  Widget build(BuildContext context) => Text(widget.label);
}

void main() {
  testWidgets('切走再切回不会重建页面', (tester) async {
    var loads = <String, int>{};
    var selected = 'a';

    Future<void> pumpStack() async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: NavPageStack(
            selectedKey: selected,
            pages: [
              NavPageEntry(
                pageKey: 'a',
                body: _Probe(label: 'a', loads: loads),
              ),
              NavPageEntry(
                pageKey: 'b',
                body: _Probe(label: 'b', loads: loads),
              ),
            ],
          ),
        ),
      );
    }

    await pumpStack();
    expect(loads['a'], 1);

    selected = 'b';
    await pumpStack();
    expect(loads['a'], 1);
    expect(loads['b'], 1);

    selected = 'a';
    await pumpStack();
    expect(loads['a'], 1);
    expect(loads['b'], 1);
  });

  testWidgets('前面的页面被移除后当前页不重建', (tester) async {
    var loads = <String, int>{};
    var selected = 'c';
    var includeA = true;

    Future<void> pumpStack() async {
      var pages = <NavPageEntry>[
        if (includeA)
          NavPageEntry(
            pageKey: 'a',
            body: _Probe(label: 'a', loads: loads),
          ),
        NavPageEntry(
          pageKey: 'c',
          body: _Probe(label: 'c', loads: loads),
        ),
      ];
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: NavPageStack(selectedKey: selected, pages: pages),
        ),
      );
    }

    await pumpStack();
    expect(loads['c'], 1);

    includeA = false;
    await pumpStack();
    expect(loads['c'], 1);
  });
}
