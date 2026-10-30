part of '../download_task_details.dart';

class _PeersTab extends StatefulWidget {
  const _PeersTab({
    required this.peers,
    required this.truncated,
    required this.loading,
    required this.onShowTrackers,
    this.trackerUrl,
    this.error,
    this.onRetry,
    super.key,
  });

  final List<BtTaskPeerDetail> peers;
  final bool truncated;
  final bool loading;
  final ValueChanged<String> onShowTrackers;
  final String? trackerUrl;
  final String? error;
  final VoidCallback? onRetry;

  @override
  State<_PeersTab> createState() => _PeersTabState();
}

class _PeersTabState extends State<_PeersTab> {
  static const _columnFlexes = [3, 2, 4, 4, 2, 2];

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
    var clients = widget.peers.map((peer) => peer.clientName).toSet().toList()
      ..sort();
    _filterController.showFlyout(
      barrierDismissible: true,
      dismissOnPointerMoveAway: false,
      dismissWithEsc: true,
      builder: (context) => MenuFlyout(
        items: [
          MenuFlyoutItem(
            leading: _filterLeading(_clientFilter == null),
            text: const Text('全部 UA 客户端'),
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
    var peers = widget.peers;
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
        2 => a.peerId.compareTo(b.peerId),
        3 => a.progress.compareTo(b.progress),
        4 => a.downloadRate.compareTo(b.downloadRate),
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
    var error = widget.error;
    if (error != null && widget.peers.isEmpty) {
      return _DetailTabError(error: error, onRetry: widget.onRetry);
    }
    if (widget.peers.isEmpty && widget.loading) {
      return const Center(child: ProgressRing());
    }
    if (widget.peers.isEmpty) {
      if (widget.trackerUrl != null) {
        return const _DetailEmptyState(
          icon: FluentIcons.people,
          title: '此 Tracker 暂无关联的 Peer',
          description: '最近返回过的节点出现在 Peer 列表时，会在这里显示',
        );
      }
      return const _DetailEmptyState(
        icon: FluentIcons.people,
        title: '暂无已连接 Peer',
        description: '建立连接后会在这里显示客户端与传输状态',
      );
    }
    var peers = _sortedPeers();
    var footerParts = <String>[
      if (widget.truncated) '可翻页查看更多 Peer',
      if (_clientFilter != null)
        '已按 UA 客户端「$_clientFilter」筛选 · '
            '显示 ${peers.length} / ${widget.peers.length} 个',
      if (error != null) '刷新失败，正在显示上次结果',
    ];
    return _TableShell(
      footer: footerParts.isEmpty ? null : footerParts.join(' · '),
      header: _TableHeader(
        columns: const ['地址', 'UA', 'Peer ID', '进度', '下载', '上传'],
        flexes: _columnFlexes,
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
          flexes: _columnFlexes,
          columns: [
            Tooltip(
              message: _diagnostics(peer),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    peer.endpointLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    _connectionLabel(peer),
                    style: BTTypography.caption(context),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: _PeerIdentityCell(
                label: 'UA',
                value: peer.userAgent,
                text: peer.userAgent.isEmpty ? '未提供' : peer.clientName,
                subtitle: peer.clientVersion,
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: _PeerIdentityCell(
                    label: 'Peer ID',
                    value: peer.peerIdLabel,
                    text: peer.peerId.isEmpty ? '等待握手' : peer.peerIdLabel,
                  ),
                ),
                Tooltip(
                  message: peer.trackerUrls.isEmpty
                      ? '暂无具体 Tracker 返回记录'
                      : '查看关联 Tracker\n${peer.trackerUrls.join('\n')}',
                  child: IconButton(
                    icon: const Icon(FluentIcons.link, size: 13),
                    onPressed: peer.trackerUrls.isEmpty
                        ? null
                        : () => widget.onShowTrackers(peer.endpoint),
                  ),
                ),
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

class _PeerIdentityCell extends StatelessWidget {
  const _PeerIdentityCell({
    required this.label,
    required this.value,
    required this.text,
    this.subtitle = '',
  });

  final String label;
  final String value;
  final String text;
  final String subtitle;

  Future<void> _copy(BuildContext context) async {
    try {
      await Clipboard.setData(ClipboardData(text: value));
      if (context.mounted) await BtInfobar.success(context, '$label 已复制');
    } catch (error) {
      if (context.mounted) await BtInfobar.error(context, '复制失败：$error');
    }
  }

  @override
  Widget build(BuildContext context) => Tooltip(
    message: value.isEmpty ? '$label 暂不可用' : '$value\n单击复制 $label',
    child: HoverButton(
      hitTestBehavior: HitTestBehavior.opaque,
      cursor: value.isEmpty
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      semanticLabel: value.isEmpty ? '$label 暂不可用' : '复制 $label：$value',
      onPressed: value.isEmpty ? null : () => unawaited(_copy(context)),
      builder: (context, states) => AnimatedContainer(
        duration: BTTheme.animationDurationFast,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: states.isHovered || states.isFocused
              ? FluentTheme.of(context).accentColor.withValues(alpha: .06)
              : Colors.transparent,
          borderRadius: BTRadius.smallBR,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: BTTypography.body(context).copyWith(fontSize: 13),
            ),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: BTTypography.caption(
                  context,
                ).copyWith(color: BTColors.textSecondary(context)),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

String _connectionLabel(BtTaskPeerDetail peer) =>
    switch (peer.connectionState) {
      'connecting' => '正在连接',
      'handshake' => '正在握手',
      _ when peer.remoteChoked => '对端暂未允许下载',
      _ when !peer.interested => '当前未请求对端数据',
      _ => peer.seed ? '种子节点' : '已连接',
    };

String _diagnostics(BtTaskPeerDetail peer) {
  var transport = switch (peer.transport) {
    'utp' => 'uTP',
    'webSeed' => 'Web Seed',
    _ => 'TCP',
  };
  var encryption = switch (peer.encryption) {
    'tls' => 'TLS',
    'rc4' => 'RC4',
    'handshake' => '仅握手混淆',
    _ => '未加密',
  };
  return '${_connectionLabel(peer)} · $transport · $encryption\n'
      '本端：${peer.interested ? '感兴趣' : '不感兴趣'} / '
      '${peer.choked ? '阻止对端下载' : '允许对端下载'}\n'
      '对端：${peer.remoteInterested ? '感兴趣' : '不感兴趣'} / '
      '${peer.remoteChoked ? '阻止本端下载' : '允许本端下载'}\n'
      '种子：${peer.seed ? '是' : '否'}\n'
      '发现来源：${peer.sources.isEmpty ? '未报告' : peer.sources.join('、')}\n'
      '近期关联 Tracker：${peer.trackerUrls.length} 个';
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
