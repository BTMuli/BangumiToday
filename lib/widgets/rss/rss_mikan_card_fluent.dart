// Dart imports:
import 'dart:ui';

// Package imports:
import 'package:file_selector/file_selector.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jiffy/jiffy.dart';
import 'package:url_launcher/url_launcher_string.dart';

// Project imports:
import '../../models/rss/rss.dart';
import '../../plugins/mikan/mikan_api.dart';
import '../../store/bt_download_store.dart';
import '../../tools/download_tool.dart';
import '../../ui/bt_infobar.dart';
import '../../utils/tool_func.dart';

class RssMikanCardFluent extends ConsumerStatefulWidget {
  final RssItem item;
  final String? dir;

  const RssMikanCardFluent({super.key, required this.item, this.dir});

  @override
  ConsumerState<RssMikanCardFluent> createState() => _RssMikanCardFluentState();
}

class _RssMikanCardFluentState extends ConsumerState<RssMikanCardFluent> {
  bool _isHovered = false;
  bool _isPressed = false;

  RssItem get item => widget.item;

  Future<void> _download(BuildContext context) async {
    if (item.enclosure?.url == null || item.title == null) return;

    var urlReal = BtrMikanApi.rewriteUrl(item.enclosure!.url!);

    String? saveDir = widget.dir;
    if (saveDir == null || saveDir.isEmpty) {
      saveDir = await getDirectoryPath();
    }

    if (saveDir == null || saveDir.isEmpty) {
      if (context.mounted) await BtInfobar.error(context, '未选择下载目录');
      return;
    }

    if (context.mounted) {
      var savePath = await BTDownloadTool().downloadRssTorrent(
        urlReal,
        item.title!,
        context: context,
      );
      if (savePath.isNotEmpty) {
        try {
          await ref
              .read(btDownloadStoreProvider)
              .addTorrentFile(
                torrentPath: savePath,
                savePath: saveDir,
                displayName: item.title,
              );
          if (context.mounted) {
            await BtInfobar.success(context, '下载任务已添加');
          }
        } catch (error) {
          if (context.mounted) {
            await BtInfobar.error(context, error.toString());
          }
        }
      }
    }
  }

  Future<void> _openLink() async {
    if (item.link == null || item.link!.isEmpty) {
      if (mounted) await BtInfobar.error(context, '链接为空');
      return;
    }

    var linkReal = BtrMikanApi.rewriteUrl(item.link!);
    await launchUrlString(linkReal);
  }

  @override
  Widget build(BuildContext context) {
    var theme = FluentTheme.of(context);
    var accentColor = theme.accentColor;

    String sizeStr = '';
    if (item.enclosure?.length != null) {
      sizeStr = filesize(item.enclosure!.length);
    }

    String pubDate = '';
    if (item.pubDate != null) {
      pubDate = Jiffy.parse(
        item.pubDate!,
        pattern: 'yyyy-MM-ddTHH:mm:ss',
      ).format(pattern: 'MM-dd HH:mm');
    }

    var backgroundColor = theme.brightness == Brightness.light
        ? Colors.white.withValues(alpha: _isHovered ? 0.95 : 0.85)
        : Colors.grey[190].withValues(alpha: _isHovered ? 0.95 : 0.85);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: theme.brightness == Brightness.light
                  ? Colors.grey[60]
                  : Colors.grey[130],
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: _isHovered ? 0.12 : 0.08),
                blurRadius: _isHovered ? 12 : 8,
                spreadRadius: 0,
                offset: Offset(0, _isHovered ? 4 : 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(7),
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: _isHovered ? 20 : 10,
                sigmaY: _isHovered ? 20 : 10,
              ),
              child: Transform.translate(
                offset: Offset(0, _isPressed ? 2.0 : 0.0),
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Tooltip(
                          message: item.title ?? '',
                          child: Text(
                            item.title ?? '',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              height: 1.4,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            FluentIcons.clock,
                            size: 12,
                            color: theme.brightness == Brightness.light
                                ? Colors.grey[130]
                                : Colors.grey[100],
                          ),
                          SizedBox(width: 4),
                          Text(
                            pubDate,
                            style: TextStyle(
                              fontSize: 11,
                              color: theme.brightness == Brightness.light
                                  ? Colors.grey[130]
                                  : Colors.grey[100],
                            ),
                          ),
                          SizedBox(width: 12),
                          Icon(
                            FluentIcons.download,
                            size: 12,
                            color: theme.brightness == Brightness.light
                                ? Colors.grey[130]
                                : Colors.grey[100],
                          ),
                          SizedBox(width: 4),
                          Text(
                            sizeStr,
                            style: TextStyle(
                              fontSize: 11,
                              color: theme.brightness == Brightness.light
                                  ? Colors.grey[130]
                                  : Colors.grey[100],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Tooltip(
                            message: '下载',
                            child: IconButton(
                              icon: Icon(
                                FluentIcons.download,
                                size: 16,
                                color: accentColor,
                              ),
                              onPressed: () => _download(context),
                            ),
                          ),
                          Tooltip(
                            message: '打开链接',
                            child: IconButton(
                              icon: Icon(
                                FluentIcons.edge_logo,
                                size: 16,
                                color: accentColor,
                              ),
                              onPressed: _openLink,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
