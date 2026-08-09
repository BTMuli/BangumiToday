part of '../download_page.dart';

class _EmptyDownloads extends StatelessWidget {
  const _EmptyDownloads({required this.store});

  final BtDownloadStore store;

  @override
  Widget build(BuildContext context) {
    var failed = store.engineState == BtEngineClientState.failed;
    var color = failed
        ? BTColors.errorLight(context)
        : FluentTheme.of(context).accentColor;
    return Center(
      child: BTCard(
        useAcrylic: false,
        useReveal: false,
        shadowLevel: BTShadowLevel.subtle,
        padding: EdgeInsets.symmetric(horizontal: 52, vertical: 42),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                failed ? FluentIcons.error : FluentIcons.cloud_download,
                size: 32,
                color: color,
              ),
            ),
            SizedBox(height: 18),
            Text(
              failed ? '下载引擎暂不可用' : '暂无下载任务',
              style: BTTypography.subtitle(context),
            ),
            SizedBox(height: 6),
            Text(
              failed
                  ? '请检查引擎状态后重试'
                  : store.engineState == BtEngineClientState.stopped
                  ? '下载引擎未开启，点击右上角引擎状态开启'
                  : '从 RSS 条目添加任务后会显示在这里',
              style: BTTypography.body(
                context,
              ).copyWith(color: BTColors.textSecondary(context)),
            ),
            if (store.lastError != null) ...[
              SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Text(
                  store.lastError!,
                  textAlign: TextAlign.center,
                  style: BTTypography.caption(context).copyWith(color: color),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyStopped extends StatelessWidget {
  const _EmptyStopped();

  @override
  Widget build(BuildContext context) {
    var color = BTColors.textTertiary(context);
    return Center(
      child: BTCard(
        useAcrylic: false,
        useReveal: false,
        shadowLevel: BTShadowLevel.subtle,
        padding: EdgeInsets.symmetric(horizontal: 52, vertical: 42),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(FluentIcons.check_mark, size: 32, color: color),
            ),
            SizedBox(height: 18),
            Text('暂无已停止任务', style: BTTypography.subtitle(context)),
            SizedBox(height: 6),
            Text(
              '下载出错或完成做种的任务会显示在这里',
              style: BTTypography.body(
                context,
              ).copyWith(color: BTColors.textSecondary(context)),
            ),
          ],
        ),
      ),
    );
  }
}
