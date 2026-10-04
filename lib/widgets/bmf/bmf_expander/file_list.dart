part of '../bmf_expander.dart';

extension _BmfFileList on _BmfFileExpanderState {
  Widget buildFileItem(BuildContext context, String file) {
    var fileState = _dirState?.stateFor(file);
    var isIncomplete = fileState?.isIncomplete ?? false;
    var isVideo = PlaybackPaths.isVideo(file);
    var statusLabel = fileState?.statusLabel ?? '下载中';
    var fileSize = _fileSizes[file];

    return Container(
      margin: EdgeInsets.only(bottom: widget.embedded ? 8 : 6),
      padding: EdgeInsets.symmetric(
        horizontal: widget.embedded ? 12 : 10,
        vertical: widget.embedded ? 12 : 8,
      ),
      decoration: BoxDecoration(
        color: BTColors.surfaceSecondary(context),
        borderRadius: widget.embedded ? BTRadius.mediumBR : BTRadius.smallBR,
        border: Border.all(color: BTColors.divider(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                isVideo ? FluentIcons.video : FluentIcons.document,
                size: 16,
                color: isIncomplete
                    ? FluentTheme.of(context).accentColor
                    : BTColors.textSecondary(context),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Tooltip(
                  message: file,
                  child: Text(
                    file,
                    style: BTTypography.body(context),
                    maxLines: widget.embedded ? 3 : 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: widget.embedded ? 8 : 6),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        if (fileSize != null)
                          Text(
                            filesize(fileSize),
                            style: BTTypography.caption(
                              context,
                            ).copyWith(color: BTColors.textTertiary(context)),
                          ),
                        if (isIncomplete)
                          Text(
                            statusLabel,
                            style: BTTypography.caption(
                              context,
                            ).copyWith(color: _statusColor(context, fileState)),
                          ),
                      ],
                    ),
                    if (isIncomplete) ...[
                      const SizedBox(height: 6),
                      ProgressBar(
                        value: fileState?.progress == null
                            ? null
                            : fileState!.progress! * 100,
                        strokeWidth: 2,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 16),
              _FileItemActions(
                file: file,
                subject: widget.subject,
                dir: widget.downloadDir,
                isVideo: isVideo,
                canOpen: isVideo && !isIncomplete,
                isIncomplete: isIncomplete,
                onDelete: refreshFiles,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _statusColor(BuildContext context, BtFileDownloadState? fileState) {
    if (fileState == null || fileState.isActive) {
      return FluentTheme.of(context).accentColor;
    }
    if (fileState.isPaused) return BTColors.warningLight(context);
    if (fileState.isFailed) return BTColors.errorLight(context);
    return FluentTheme.of(context).accentColor;
  }

  Widget buildContent() {
    if (files.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text('没有找到任何文件', style: BTTypography.body(context)),
      );
    }

    if (!widget.contentScrollable || files.length <= 6) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: files.map((f) => buildFileItem(context, f)).toList(),
      );
    }

    return SizedBox(
      height: widget.maxHeight,
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: files.length,
        itemBuilder: (context, index) {
          return buildFileItem(context, files[index]);
        },
      ),
    );
  }

  Widget _buildCountBadge(BuildContext context, int count) {
    var accentColor = FluentTheme.of(context).accentColor;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: accentColor,
        ),
      ),
    );
  }

  Widget _buildDownloadingBadge(BuildContext context, String label) {
    var accentColor = FluentTheme.of(context).accentColor;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: accentColor,
        borderRadius: BTRadius.roundBR,
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
