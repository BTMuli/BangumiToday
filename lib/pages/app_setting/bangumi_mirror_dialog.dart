// Package imports:
import 'package:fluent_ui/fluent_ui.dart';

// Project imports:
import '../../models/app/bangumi_mirror.dart';

Future<BangumiMirror?> showBangumiMirrorDialog(
  BuildContext context, {
  required BangumiMirrorType type,
  required BangumiMirrorCatalog catalog,
  BangumiMirror? mirror,
}) => showDialog<BangumiMirror>(
  context: context,
  builder: (_) =>
      _BangumiMirrorDialog(type: type, catalog: catalog, mirror: mirror),
);

class _BangumiMirrorDialog extends StatefulWidget {
  const _BangumiMirrorDialog({
    required this.type,
    required this.catalog,
    this.mirror,
  });

  final BangumiMirrorType type;
  final BangumiMirrorCatalog catalog;
  final BangumiMirror? mirror;

  @override
  State<_BangumiMirrorDialog> createState() => _BangumiMirrorDialogState();
}

class _BangumiMirrorDialogState extends State<_BangumiMirrorDialog> {
  late final _name = TextEditingController(text: widget.mirror?.name);
  late final _url = TextEditingController(text: widget.mirror?.url);
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _url.dispose();
    super.dispose();
  }

  void _submit() {
    try {
      var mirror = BangumiMirror(name: _name.text, url: _url.text);
      widget.catalog.save(widget.type, mirror, originalUrl: widget.mirror?.url);
      Navigator.of(context).pop(mirror);
    } on FormatException catch (error) {
      setState(() => _error = error.message);
    }
  }

  @override
  Widget build(BuildContext context) => ContentDialog(
    title: Text('${widget.mirror == null ? '新增' : '编辑'}${widget.type.label}'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InfoLabel(
            label: '名称',
            child: TextBox(
              controller: _name,
              autofocus: true,
              placeholder: '我的镜像',
              onSubmitted: (_) => _submit(),
            ),
          ),
          const SizedBox(height: 12),
          InfoLabel(
            label: '地址',
            child: TextBox(
              controller: _url,
              placeholder: 'https://example.com',
              onSubmitted: (_) => _submit(),
            ),
          ),
          const SizedBox(height: 8),
          const Text('填写 HTTP/HTTPS 域名，可带端口，不含路径、查询参数或账号密码。'),
          if (_error != null) ...[
            const SizedBox(height: 12),
            InfoBar(title: Text(_error!), severity: InfoBarSeverity.error),
          ],
        ],
      ),
    ),
    actions: [
      Button(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('取消'),
      ),
      FilledButton(onPressed: _submit, child: const Text('保存')),
    ],
  );
}
