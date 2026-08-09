part of '../download_task_details.dart';

class _PeersTab extends StatefulWidget {
  const _PeersTab({required this.details});

  final BtTaskDetails details;

  @override
  State<_PeersTab> createState() => _PeersTabState();
}

class _PeersTabState extends State<_PeersTab> {
  final FlyoutController _filterController = FlyoutController();
  var _sortIndex = -1;
  var _ascending = true;
  String? _clientFilter;

  @override
  void dispose() {
    _filterController.dispose();
    super.dispose();
  }

  void _toggleSort(int index) {
    setState(() {
      if (_sortIndex == index) {
        _ascending = !_ascending;
      } else {
        _sortIndex = index;
        _ascending = true;
      }
    });
  }

  void _openClientFilter() {
    var clients =
        widget.details.peers.map((peer) => peer.clientName).toSet().toList()
          ..sort();
    _filterController.showFlyout(
      barrierDismissible: true,
      dismissOnPointerMoveAway: false,
      dismissWithEsc: true,
      builder: (context) => MenuFlyout(
        items: [
          MenuFlyoutItem(
            leading: _filterLeading(_clientFilter == null),
            text: const Text('全部客户端'),
            onPressed: () {
              if (!mounted) return;
              setState(() => _clientFilter = null);
            },
          ),
          if (clients.isNotEmpty) const MenuFlyoutSeparator(),
          for (var client in clients)
            MenuFlyoutItem(
              leading: _filterLeading(_clientFilter == client),
              text: Text(client, maxLines: 1, overflow: TextOverflow.ellipsis),
              onPressed: () {
                if (!mounted) return;
                setState(() => _clientFilter = client);
              },
            ),
        ],
      ),
    );
  }

  Widget _filterLeading(bool active) {
    return SizedBox(
      width: 18,
      child: active
          ? Icon(
              FluentIcons.check_mark,
              size: 13,
              color: FluentTheme.of(context).accentColor,
            )
          : null,
    );
  }

  List<BtTaskPeerDetail> _sortedPeers() {
    var peers = widget.details.peers;
    var clientFilter = _clientFilter;
    if (clientFilter != null) {
      peers = peers.where((peer) => peer.clientName == clientFilter).toList();
    }
    if (_sortIndex == -1) return peers;
    var sorted = List<BtTaskPeerDetail>.of(peers);
    sorted.sort((a, b) {
      var result = switch (_sortIndex) {
        0 => a.endpoint.toLowerCase().compareTo(b.endpoint.toLowerCase()),
        1 => _compareClient(a, b),
        2 => a.progress.compareTo(b.progress),
        3 => a.downloadRate.compareTo(b.downloadRate),
        _ => a.uploadRate.compareTo(b.uploadRate),
      };
      return _ascending ? result : -result;
    });
    return sorted;
  }

  static int _compareClient(BtTaskPeerDetail a, BtTaskPeerDetail b) {
    var nameResult = a.clientName.toLowerCase().compareTo(
      b.clientName.toLowerCase(),
    );
    if (nameResult != 0) return nameResult;
    return a.clientVersion.toLowerCase().compareTo(
      b.clientVersion.toLowerCase(),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.details.peers.isEmpty) {
      return const _DetailEmptyState(
        icon: FluentIcons.people,
        title: '暂无已连接 Peer',
        description: '建立连接后会在这里显示客户端与传输状态',
      );
    }
    var peers = _sortedPeers();
    var footerParts = <String>[
      if (widget.details.peersTruncated) 'Peer 较多，仅显示前 500 个',
      if (_clientFilter != null)
        '已按客户端「$_clientFilter」筛选 · 显示 ${peers.length} / ${widget.details.peers.length} 个',
    ];
    return _TableShell(
      footer: footerParts.isEmpty ? null : footerParts.join(' · '),
      header: _TableHeader(
        columns: const ['地址', '客户端', '进度', '下载', '上传'],
        flexes: const [3, 3, 2, 2, 2],
        sortIndex: _sortIndex,
        ascending: _ascending,
        onSort: _toggleSort,
        filterIndex: 1,
        filterActive: _clientFilter != null,
        onFilter: (_) => _openClientFilter(),
        filterController: _filterController,
      ),
      itemCount: peers.length,
      itemBuilder: (context, index) {
        var peer = peers[index];
        var progress = (peer.progress * 100).clamp(0, 100).toDouble();
        return _TableRow(
          flexes: const [3, 3, 2, 2, 2],
          columns: [
            Text(
              peer.endpointLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  peer.clientName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (peer.clientVersion.isNotEmpty) ...[
                  SizedBox(height: 2),
                  Text(
                    peer.clientVersion,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: BTTypography.caption(
                      context,
                    ).copyWith(color: BTColors.textSecondary(context)),
                  ),
                ],
              ],
            ),
            Padding(
              padding: EdgeInsets.only(right: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${progress.toStringAsFixed(0)}%',
                    style: BTTypography.caption(context),
                  ),
                  SizedBox(height: 4),
                  ProgressBar(value: progress, strokeWidth: 4),
                ],
              ),
            ),
            _RateText(
              value: peer.downloadRate,
              color: FluentTheme.of(context).accentColor,
            ),
            _RateText(
              value: peer.uploadRate,
              color: BTColors.successLight(context),
            ),
          ],
        );
      },
    );
  }
}

class _RateText extends StatelessWidget {
  const _RateText({required this.value, required this.color});

  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      '${BTFileTool.formatSize(value)}/s',
      style: BTTypography.caption(context).copyWith(
        color: value > 0 ? color : BTColors.textTertiary(context),
        fontWeight: value > 0 ? FontWeight.w600 : FontWeight.w400,
      ),
    );
  }
}
