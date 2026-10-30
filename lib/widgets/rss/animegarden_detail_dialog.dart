// Dart imports:
import 'dart:async';

// Flutter imports:
import 'package:flutter/services.dart';

// Package imports:
import 'package:dio/dio.dart';
import 'package:fluent_ui/fluent_ui.dart';

// Project imports:
import '../../core/theme/bt_theme.dart';
import '../../models/rss/animegarden_detail.dart';
import '../../models/rss/animegarden_resource.dart';
import '../../request/rss/animegarden_api.dart';
import '../../ui/bt_infobar.dart';
import 'rss_release_data.dart';
import 'rss_release_detail_dialog.dart';

/// Loads one selected resource, without fetching details for list rows.
class AnimeGardenDetailDialog extends StatefulWidget {
  const AnimeGardenDetailDialog({
    super.key,
    required this.resource,
    required this.release,
    required this.onTapUrl,
    required this.actions,
  });

  final AnimeGardenResource resource;
  final RssReleaseData release;
  final Future<bool> Function(String url) onTapUrl;
  final Widget actions;

  @override
  State<AnimeGardenDetailDialog> createState() =>
      _AnimeGardenDetailDialogState();
}

class _AnimeGardenDetailDialogState extends State<AnimeGardenDetailDialog> {
  final _api = AnimeGardenAPI();
  CancelToken? _token;
  AnimeGardenDetailResponse? _response;
  bool _loading = true;
  String? _error;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _generation++;
    _token?.cancel('资源详情已关闭');
    _api.client.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    var generation = ++_generation;
    _token?.cancel('重试资源详情');
    var token = _token = CancelToken();
    setState(() {
      _loading = true;
      _error = null;
    });
    var result = await _api.detail(
      widget.resource.provider,
      widget.resource.providerId,
      cancelToken: token,
    );
    if (!mounted || generation != _generation) return;
    setState(() {
      _loading = false;
      if (result.code == 0 && result.data is AnimeGardenDetailResponse) {
        _response = result.data as AnimeGardenDetailResponse;
      } else {
        _error = result.message;
      }
    });
  }

  Widget? _status() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [ProgressRing(), SizedBox(height: 12), Text('正在加载资源详情…')],
          ),
        ),
      );
    }
    var message =
        _error ??
        (_response?.detail == null
            ? _response?.isDeleted == true
                  ? '该资源已在来源站标记删除，站点未返回详细内容。'
                  : '站点尚未提供该资源的详细内容，可稍后重试或打开上游页面。'
            : null);
    if (message != null) {
      return InfoBar(
        title: Text(message),
        severity: _error == null && _response?.isDeleted != true
            ? InfoBarSeverity.info
            : InfoBarSeverity.warning,
        action: Tooltip(
          message: '重新加载资源详情',
          child: IconButton(
            icon: const Icon(
              FluentIcons.refresh,
              size: 16,
              semanticLabel: '重新加载资源详情',
            ),
            onPressed: _load,
          ),
        ),
      );
    }
    if (_response?.isDeleted == true) {
      return const InfoBar(
        title: Text('该资源已在来源站标记删除，当前显示已取得的详情。'),
        severity: InfoBarSeverity.warning,
      );
    }
    return null;
  }

  Future<void> _copyMagnet(String url) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (mounted) await BtInfobar.success(context, '磁力链接已复制');
  }

  Widget _files(AnimeGardenDetail detail) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (detail.files.isNotEmpty || detail.hasMoreFiles) ...[
        const SizedBox(height: 16),
        Expander(
          initiallyExpanded: false,
          header: Text(
            '文件清单（${detail.files.length}）',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          contentBackgroundColor: BTColors.surfaceTertiary(context),
          contentPadding: const EdgeInsets.all(12),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (detail.files.isNotEmpty)
                Builder(
                  builder: (context) {
                    var rowHeight =
                        MediaQuery.textScalerOf(context).scale(14) + 12;
                    return SizedBox(
                      height: (detail.files.length * (rowHeight + 8) - 8).clamp(
                        rowHeight,
                        256.0,
                      ),
                      child: ListView.separated(
                        primary: false,
                        itemCount: detail.files.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (_, index) {
                          var file = detail.files[index];
                          return SizedBox(
                            height: rowHeight,
                            child: Row(
                              children: [
                                Expanded(
                                  child: Tooltip(
                                    message: file.name,
                                    child: SelectionArea(
                                      child: Text(
                                        file.name,
                                        maxLines: 1,
                                        softWrap: false,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                ),
                                if (file.size.isNotEmpty) ...[
                                  const SizedBox(width: 12),
                                  Tooltip(
                                    message: '文件大小：${file.size}',
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          FluentIcons.database,
                                          size: 12,
                                          color: BTColors.textSecondary(
                                            context,
                                          ),
                                          semanticLabel: '文件大小',
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          file.size,
                                          maxLines: 1,
                                          softWrap: false,
                                          style: BTTypography.caption(context),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              if (detail.hasMoreFiles) ...[
                const SizedBox(height: 8),
                const Text('文件清单未完整返回，可打开上游页面查看其余文件。'),
              ],
            ],
          ),
        ),
      ],
      if (detail.magnets.isNotEmpty) ...[
        const SizedBox(height: 16),
        Expander(
          header: Text('磁力链接（${detail.magnets.length}）'),
          content: SizedBox(
            height: (detail.magnets.length * 72.0).clamp(72.0, 240.0),
            child: ListView.builder(
              primary: false,
              itemCount: detail.magnets.length,
              itemBuilder: (_, index) {
                var magnet = detail.magnets[index];
                return Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            magnet.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SelectableText(magnet.url, maxLines: 2),
                        ],
                      ),
                    ),
                    Tooltip(
                      message: '复制磁力链接',
                      child: IconButton(
                        icon: const Icon(
                          FluentIcons.copy,
                          size: 16,
                          semanticLabel: '复制磁力链接',
                        ),
                        onPressed: () => _copyMagnet(magnet.url),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    ],
  );

  @override
  Widget build(BuildContext context) {
    var detail = _response?.detail;
    return RssReleaseDetailDialog(
      release: widget.release,
      onTapUrl: widget.onTapUrl,
      actions: widget.actions,
      baseUrl: Uri.tryParse(_response?.resource.href ?? widget.resource.href),
      descriptionOverride: detail?.description,
      status: _status(),
      extraContent: detail == null ? null : _files(detail),
    );
  }
}
