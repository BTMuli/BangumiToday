// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../core/constants/app_constants.dart';
import '../../domain/repositories/bmf_repository.dart';
import '../../store/app_store.dart';
import '../../ui/bt_dialog.dart';
import '../../ui/bt_infobar.dart';

Future<void> applyMikanMirror({
  required WidgetRef ref,
  required BuildContext context,
  required String input,
}) async {
  var url = BTAppConstants.normalizeMikanUrl(input);
  var current = BTAppConstants.normalizeMikanUrl(
    ref.read(appStoreProvider).mikanRss,
  );
  if (url == current) {
    if (context.mounted) await BtInfobar.warn(context, 'URL 未变更');
    return;
  }
  await ref.read(bmfRepositoryProvider).updateMikanUrl(url, current);
  await ref.read(appStoreProvider.notifier).setMikanRss(url);
  if (context.mounted) {
    await BtInfobar.success(context, 'Mikan 镜像站已更新');
  }
}

class MikanMirrorCombo extends ConsumerWidget {
  final bool showCustomButton;

  const MikanMirrorCombo({super.key, this.showCustomButton = true});

  Future<void> tryEditUrl(BuildContext context, WidgetRef ref) async {
    var current = ref.read(appStoreProvider).mikanRss;
    var input = await showInput(
      context,
      title: '输入 URL',
      content:
          '请输入你的 Mikan URL\n（默认为 '
          '${BTAppConstants.defaultMikanMirror}）',
      value: current,
    );
    if (input == null || input == '') {
      if (!context.mounted) return;
      var check = await showConfirm(
        context,
        title: '确认清空 URL？',
        content: '将使用默认地址 ${BTAppConstants.defaultMikanMirror}',
      );
      if (!check) return;
      if (!context.mounted) return;
      await applyMikanMirror(
        ref: ref,
        context: context,
        input: BTAppConstants.defaultMikanMirror,
      );
      return;
    }
    if (!context.mounted) return;
    await applyMikanMirror(ref: ref, context: context, input: input);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var current = BTAppConstants.normalizeMikanUrl(
      ref.watch(appStoreProvider).mikanRss,
    );
    var values = BTAppConstants.mikanMirrorChoices(current);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ComboBox<String>(
          value: current,
          items: [
            for (var value in values)
              ComboBoxItem(
                value: value,
                child: Text(BTAppConstants.mikanMirrorLabel(value)),
              ),
          ],
          onChanged: (value) async {
            if (value == null || value == current) return;
            await applyMikanMirror(ref: ref, context: context, input: value);
          },
        ),
        if (showCustomButton) ...[
          SizedBox(width: 8),
          Tooltip(
            message: '自定义镜像',
            child: IconButton(
              icon: const Icon(FluentIcons.edit, size: 15),
              onPressed: () => tryEditUrl(context, ref),
            ),
          ),
        ],
      ],
    );
  }
}
