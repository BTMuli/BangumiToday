part of '../bmf_expander.dart';

extension _BmfFileList on _BmfFileExpanderState {
  Widget buildFileItem(BuildContext context, String file) {
    var state = _dirState?.stateFor(file);
    var incomplete = state?.isIncomplete ?? false;
    var video = PlaybackPaths.isVideo(file);
    return Padding(
      padding: EdgeInsets.only(bottom: widget.embedded ? 8 : 6),
      child: BmfFileItem(
        file: file,
        fileSize: _fileSizes[file],
        state: state,
        spacious: widget.embedded,
        actions: _FileItemActions(
          file: file,
          subject: widget.subject,
          dir: widget.downloadDir,
          isVideo: video,
          canOpen: video && !incomplete,
          isIncomplete: incomplete,
          onDelete: refreshFiles,
        ),
      ),
    );
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
