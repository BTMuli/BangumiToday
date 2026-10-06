part of '../subject_detail_resources.dart';

extension _ResourceActions on _SubjectDetailResourcesState {
  Future<AppBmfModel> _currentModel() async =>
      await ref.read(bmfRepositoryProvider).read(widget.subjectId) ??
      _emptyModel();

  Future<void> _searchRss() async {
    await widget.onSearchRss();
    if (mounted) await _loadModel();
  }

  Future<void> _addRss() async {
    var value = await showInput(
      context,
      title: '添加 RSS 订阅',
      content: '输入 RSS 地址',
    );
    var url = value?.trim();
    if (url == null || url.isEmpty || !mounted) return;
    var uri = Uri.tryParse(url);
    if (uri == null ||
        !['https', 'http'].contains(uri.scheme) ||
        uri.host.isEmpty) {
      await BtInfobar.error(context, '请输入有效的 RSS 地址');
      return;
    }
    var repo = ref.read(bmfRepositoryProvider);
    if (await repo.checkRss(url, excludeSubject: widget.subjectId)) {
      if (mounted) await BtInfobar.error(context, '该 RSS 已被其他条目使用');
      return;
    }
    var current = await _currentModel();
    var added = AppSubscriptionModel.forUrl(url);
    if (current.subscriptions.any((s) => s.feedKey == added.feedKey)) {
      if (mounted) await BtInfobar.error(context, '该 RSS 已在订阅列表中');
      return;
    }
    var model = current.copyWith(
      subscriptions: [...current.subscriptions, added],
    );
    var scheduled = await repo.write(model);
    if (!scheduled) await repo.refreshRss(model);
    if (mounted) await _loadModel();
  }

  Future<void> _chooseDirectory() async {
    var directory = await pickDownloadDirectory(currentPath: _bmf.download);
    if (directory == null || !mounted) return;
    var repo = ref.read(bmfRepositoryProvider);
    if (await repo.checkDir(directory, excludeSubject: widget.subjectId)) {
      if (mounted) await BtInfobar.error(context, '该目录已被其他条目使用');
      return;
    }
    var model = await _currentModel();
    await repo.write(model.copyWith(download: directory));
    if (mounted) await _loadModel();
  }

  Future<void> _editTitle() async {
    var title = await showInput(
      context,
      title: '修改下载与订阅标题',
      value: _bmf.title ?? widget.title,
      content: '',
    );
    if (title == null || title.trim().isEmpty || !mounted) return;
    var model = await _currentModel();
    await ref
        .read(bmfRepositoryProvider)
        .write(model.copyWith(title: title.trim()));
    if (mounted) await _loadModel();
  }

  Future<void> _removeModel() async {
    var confirmed = await showConfirm(
      context,
      title: '清除下载与订阅配置',
      content: '确定清除该条目的订阅及下载目录记录吗？',
    );
    if (!confirmed || !mounted) return;
    var model = await _currentModel();
    if (!mounted) return;
    var deleteDirectory = await _confirmDirectoryDeletion(model.download);
    if (!mounted) return;
    var repo = ref.read(bmfRepositoryProvider);
    if (deleteDirectory) await _fileTool.deleteDir(model.download!);
    await repo.delete(widget.subjectId);
    if (mounted) await _loadModel();
  }

  Future<bool> _confirmDirectoryDeletion(String? directory) async {
    if (directory == null || directory.isEmpty) return false;
    return showConfirmAction(
      context,
      title: '删除下载目录',
      content: '是否同时删除下载目录及其中的所有文件？\n$directory',
      confirmText: '删除目录',
      cancelText: '保留文件',
    );
  }

  Future<void> _removeSubscription(int id) async {
    var confirmed = await showConfirm(
      context,
      title: '删除 RSS 订阅',
      content: '确定删除该订阅吗？',
    );
    if (!confirmed || !mounted) return;
    var model = await _currentModel();
    await ref
        .read(bmfRepositoryProvider)
        .write(
          model.copyWith(
            subscriptions: model.subscriptions
                .where((s) => s.id != id)
                .toList(),
          ),
        );
    if (mounted) await _loadModel();
  }

  Future<void> _removeDirectory() async {
    var confirmed = await showConfirm(
      context,
      title: '移除下载目录',
      content: '确定移除该条目的下载目录记录吗？',
    );
    if (!confirmed || !mounted) return;
    var model = await _currentModel();
    if (!mounted) return;
    var deleteDirectory = await _confirmDirectoryDeletion(model.download);
    if (!mounted) return;
    var repo = ref.read(bmfRepositoryProvider);
    if (deleteDirectory) await _fileTool.deleteDir(model.download!);
    await repo.write(model.copyWith(download: null));
    if (mounted) await _loadModel();
  }

  Future<void> _refreshRss() async {
    var id = _rss.selectedSubscriptionId;
    if (_refreshingRss || id == null) return;
    _update(() => _refreshingRss = true);
    try {
      var success = await BmfRssService.instance.refreshSubscription(id);
      if (!mounted) return;
      await _rss.load();
      if (!mounted) return;
      if (success) {
        await BtInfobar.success(context, 'RSS 刷新成功');
      } else {
        await BtInfobar.error(context, 'RSS 刷新失败');
      }
    } catch (error) {
      if (mounted) await BtInfobar.error(context, error.toString());
    } finally {
      if (mounted) _update(() => _refreshingRss = false);
    }
  }

  String _sourceUrl(String url, RssReleaseSource source) =>
      source == RssReleaseSource.mikan ? BtrMikanApi.rewriteUrl(url) : url;

  Future<bool> _openLink(String url, RssReleaseSource source) async {
    var uri = Uri.tryParse(url);
    if (uri == null ||
        !['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty) {
      return false;
    }
    try {
      var opened = await launchUrlString(_sourceUrl(url, source));
      if (!opened && mounted) await BtInfobar.error(context, '无法打开链接');
      return opened;
    } catch (error) {
      if (mounted) await BtInfobar.error(context, error.toString());
      return false;
    }
  }

  Future<void> _markHandled(RssReleaseData release, int? subscriptionId) async {
    if (subscriptionId == null) return;
    // 下载完成前可能已切换来源，仍标记发起下载的订阅。
    await appSubscriptionStorage.markHandled(
      subscriptionId,
      itemKeys: [_rss.itemKey(release.item)],
    );
    await BmfRssService.instance.notifySubscriptionStateChanged(subscriptionId);
    if (mounted && subscriptionId == _rss.selectedSubscriptionId) {
      await _rss.load();
    }
  }

  Future<void> _download(
    RssReleaseData release,
    RssReleaseSource source,
    int? subscriptionId,
  ) async {
    var key = (subscriptionId, release.key);
    if (!release.canDownload || _downloading.contains(key)) return;
    var directory = _bmf.download;
    if (directory == null || directory.isEmpty) {
      await BtInfobar.error(context, '请先设置下载目录');
      return;
    }
    _update(() => _downloading.add(key));
    try {
      var url = _sourceUrl(release.downloadUrl!, source);
      var store = ref.read(btDownloadStoreProvider.notifier);
      if (Uri.parse(url).scheme == 'magnet') {
        await store.addMagnet(
          uri: url,
          savePath: directory,
          displayName: release.title,
          subjectId: widget.subjectId,
        );
      } else {
        var torrent = await BTDownloadTool().downloadRssTorrent(
          url,
          release.title,
          context: context,
        );
        if (!mounted || torrent.isEmpty) return;
        await store.addTorrentFile(
          torrentPath: torrent,
          savePath: directory,
          displayName: release.title,
          subjectId: widget.subjectId,
        );
      }
      await _markHandled(release, subscriptionId);
      if (mounted) await BtInfobar.success(context, '下载任务已添加');
    } catch (error) {
      if (mounted) await BtInfobar.error(context, error.toString());
    } finally {
      if (mounted) _update(() => _downloading.remove(key));
    }
  }

  Future<void> _showReleaseDetails(
    RssReleaseData release,
    RssReleaseSource source,
    int? subscriptionId,
  ) async {
    var baseUrl = release.detailUrl ?? _rss.rssUrl;
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      dismissWithEsc: true,
      builder: (dialogContext) => RssReleaseDetailDialog(
        release: release,
        markdownDescription:
            source == RssReleaseSource.anibt || release.item.anibt != null,
        baseUrl: Uri.tryParse(_sourceUrl(baseUrl, source)),
        onTapUrl: (url) => _openLink(url, source),
        actions: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (release.canDownload)
              Button(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  unawaited(_download(release, source, subscriptionId));
                },
                child: const Text('下载'),
              ),
            const SizedBox(width: 8),
            Button(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('关闭'),
            ),
          ],
        ),
      ),
    );
  }
}
