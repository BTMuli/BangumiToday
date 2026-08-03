// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../store/bt_download_store.dart';
import 'bt_dialog.dart';
import 'bt_infobar.dart';

/// 手动开启下载引擎的统一 UI 流程：启动引擎并自动注册防火墙规则。
///
/// 规则注册失败（例如用户取消管理员授权）时，询问是否仍要开启：
/// - 选择「仍然开启」：引擎保持运行，返回 true；
/// - 选择「关闭引擎」：回滚引擎状态（停止进程并持久化关闭），返回 false。
///
/// 返回引擎最终是否处于开启状态。
Future<bool> enableDownloadEngine(WidgetRef ref, BuildContext context) async {
  String? warning;
  try {
    warning = await ref.read(btDownloadStoreProvider).enableEngine();
  } catch (error) {
    if (context.mounted) {
      await BtInfobar.error(context, '开启下载引擎失败：$error');
    }
    return false;
  }

  if (warning == null) {
    if (context.mounted) {
      await BtInfobar.success(context, '下载引擎已开启');
    }
    return true;
  }

  if (!context.mounted) return false;
  var proceed = await showConfirmAction(
    context,
    title: '防火墙规则注册失败',
    content: '$warning\n\n是否仍然开启下载引擎？',
    confirmText: '仍然开启',
    cancelText: '关闭引擎',
  );
  if (proceed) {
    if (context.mounted) {
      await BtInfobar.warn(context, '下载引擎已开启，但防火墙规则未注册');
    }
    return true;
  }

  try {
    await ref.read(btDownloadStoreProvider).disableEngine();
    if (context.mounted) {
      await BtInfobar.warn(context, '已关闭下载引擎');
    }
  } catch (error) {
    if (context.mounted) {
      await BtInfobar.error(context, '关闭下载引擎失败：$error');
    }
  }
  return false;
}
