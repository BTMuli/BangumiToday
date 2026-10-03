// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import 'subject_layout_mode.dart';

/// 条目详情页头的原版 / 新布局切换。
class SdpLayoutSwitcher extends ConsumerWidget {
  const SdpLayoutSwitcher({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var mode = ref.watch(subjectDetailLayoutModeProvider);
    var usingNew = mode == SubjectDetailLayoutMode.a;
    return Tooltip(
      message: usingNew
          ? SubjectDetailLayoutMode.a.tooltip
          : SubjectDetailLayoutMode.current.tooltip,
      child: ToggleButton(
        key: const ValueKey('subject-layout-toggle'),
        checked: usingNew,
        onChanged: (checked) {
          ref
              .read(subjectDetailLayoutModeProvider.notifier)
              .setMode(
                checked
                    ? SubjectDetailLayoutMode.a
                    : SubjectDetailLayoutMode.current,
              );
        },
        child: const Text('新布局'),
      ),
    );
  }
}
