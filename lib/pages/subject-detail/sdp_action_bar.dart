// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../core/theme/bt_theme.dart';
import '../../models/bangumi/bangumi_enum.dart';
import '../../models/database/app_bmf_model.dart';
import '../../providers/app_providers.dart';
import 'sdp_view_data.dart';
import 'subject_stat_providers.dart';

enum SdpPrimaryAction { subscribe, collect, progress, openBmf }

SdpPrimaryAction sdpResolvePrimaryAction({
  required bool loggedIn,
  required bool collected,
  required BangumiCollectionType type,
  required bool hasBmf,
}) {
  if (hasBmf && type == BangumiCollectionType.doing) {
    return SdpPrimaryAction.progress;
  }
  if (hasBmf) return SdpPrimaryAction.openBmf;
  if (loggedIn && !collected) return SdpPrimaryAction.collect;
  if (!loggedIn) return SdpPrimaryAction.subscribe;
  return SdpPrimaryAction.subscribe;
}

bool sdpBmfConfigured(AppBmfModel? bmf) {
  if (bmf == null || bmf.id == -1) return false;
  var hasRss = bmf.rss != null && bmf.rss!.isNotEmpty;
  var hasDir = bmf.download != null && bmf.download!.isNotEmpty;
  return hasRss || hasDir;
}

/// 收藏 / 进度 / BMF，按状态只强调一个主操作。
class SdpActionBar extends StatelessWidget {
  const SdpActionBar({
    super.key,
    required this.view,
    required this.hasBmf,
    this.pendingCount = 0,
    this.onProgressTap,
    this.onOpenBmf,
  });

  final SubjectDetailViewData view;
  final bool hasBmf;
  final int pendingCount;
  final VoidCallback? onProgressTap;
  final VoidCallback? onOpenBmf;

  @override
  Widget build(BuildContext context) {
    return _SdpActionBarBody(
      view: view,
      hasBmf: hasBmf,
      pendingCount: pendingCount,
      onProgressTap: onProgressTap,
      onOpenBmf: onOpenBmf ?? view.openBmfDrawer,
    );
  }
}

class _SdpActionBarBody extends StatefulWidget {
  const _SdpActionBarBody({
    required this.view,
    required this.hasBmf,
    required this.pendingCount,
    required this.onProgressTap,
    required this.onOpenBmf,
  });

  final SubjectDetailViewData view;
  final bool hasBmf;
  final int pendingCount;
  final VoidCallback? onProgressTap;
  final VoidCallback onOpenBmf;

  @override
  State<_SdpActionBarBody> createState() => _SdpActionBarBodyState();
}

class _SdpActionBarBodyState extends State<_SdpActionBarBody> {
  VoidCallback? _removeCollectListener;

  SubjectDetailViewData get view => widget.view;

  SubjectCollectStatProvider get collect => view.collectProvider;

  @override
  void initState() {
    super.initState();
    _listen();
  }

  @override
  void didUpdateWidget(covariant _SdpActionBarBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(
      oldWidget.view.collectProvider,
      widget.view.collectProvider,
    )) {
      _removeCollectListener?.call();
      _listen();
    }
  }

  @override
  void dispose() {
    _removeCollectListener?.call();
    super.dispose();
  }

  void _listen() {
    _removeCollectListener = collect.addListener((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    var loggedIn = view.user != null;
    var collected = collect.collected;
    var type = collect.type;
    var primary = sdpResolvePrimaryAction(
      loggedIn: loggedIn,
      collected: collected,
      type: type,
      hasBmf: widget.hasBmf,
    );
    return Container(
      key: const ValueKey('subject-action-bar'),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: BTColors.surfaceSecondary(context),
        borderRadius: BTRadius.mediumBR,
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (!loggedIn)
            Text(
              '登录后追番',
              key: const ValueKey('subject-action-login-hint'),
              style: BTTypography.caption(context),
            )
          else
            view.buildCollection(
              compact: true,
              filled: primary == SdpPrimaryAction.collect,
            ),
          if (collected) _buildProgressChip(context, primary),
          _buildBmfButton(context, primary),
        ],
      ),
    );
  }

  Widget _buildProgressChip(BuildContext context, SdpPrimaryAction primary) {
    var total = view.subject.totalEpisodes;
    if (total <= 0) total = view.subject.eps;
    var done = collect.epStatus;
    var label = total > 0 ? '$done/$total' : '$done';
    var isPrimary = primary == SdpPrimaryAction.progress;
    return _ActionButton(
      label: '进度 $label',
      isPrimary: isPrimary,
      onPressed: widget.onProgressTap,
    );
  }

  Widget _buildBmfButton(BuildContext context, SdpPrimaryAction primary) {
    var isPrimary =
        primary == SdpPrimaryAction.openBmf ||
        primary == SdpPrimaryAction.subscribe;
    String label;
    if (!widget.hasBmf) {
      label = '订阅下载';
    } else if (widget.pendingCount > 0) {
      label = 'BMF · 待处理 ${widget.pendingCount}';
    } else {
      label = '打开 BMF';
    }
    return _ActionButton(
      key: const ValueKey('subject-action-bmf'),
      label: label,
      isPrimary: isPrimary,
      onPressed: widget.onOpenBmf,
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    super.key,
    required this.label,
    required this.isPrimary,
    this.onPressed,
  });

  final String label;
  final bool isPrimary;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    if (isPrimary) {
      return FilledButton(onPressed: onPressed, child: Text(label));
    }
    return Button(onPressed: onPressed, child: Text(label));
  }
}

class SdpBmfStatusBar extends ConsumerWidget {
  const SdpBmfStatusBar({
    super.key,
    required this.subjectId,
    required this.child,
  });

  final int subjectId;
  final Widget Function(bool hasBmf) child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var list = ref
        .watch(bmfListProvider)
        .maybeWhen(data: (items) => items, orElse: () => const <AppBmfModel>[]);
    AppBmfModel? match;
    for (var item in list) {
      if (item.subject == subjectId) {
        match = item;
        break;
      }
    }
    return child(sdpBmfConfigured(match));
  }
}
