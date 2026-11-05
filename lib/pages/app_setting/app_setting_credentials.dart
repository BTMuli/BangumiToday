// Dart imports:
import 'dart:async';

// Package imports:
import 'package:fluent_ui/fluent_ui.dart';
import 'package:url_launcher/url_launcher_string.dart';

// Project imports:
import '../../database/app/app_mikan_credential.dart';
import '../../ui/bt_dialog.dart';
import '../../ui/bt_icon.dart';
import '../../ui/bt_infobar.dart';
import '../../widgets/common/bt_setting_section.dart';

/// 设置页「订阅源凭证」：汇总第三方订阅 Token。
class AppConfigCredentialsWidget extends StatefulWidget {
  /// 构造函数
  const AppConfigCredentialsWidget({super.key});

  @override
  State<AppConfigCredentialsWidget> createState() =>
      _AppConfigCredentialsWidgetState();
}

class _AppConfigCredentialsWidgetState
    extends State<AppConfigCredentialsWidget> {
  final BtsMikanCredential _credential = BtsMikanCredential();

  String? _token;
  bool _loaded = false;
  bool _busy = false;

  bool get _hasToken => _token != null && _token!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    unawaited(_reload());
  }

  Future<void> _reload() async {
    var value = await _credential.readToken();
    if (!mounted) return;
    setState(() {
      _token = value;
      _loaded = true;
    });
  }

  /// 从粘贴内容解析 Token（支持完整 RSS URL）。
  Future<String> _parseToken(String input) async {
    if (await canLaunchUrlString(input)) {
      var link = Uri.parse(input);
      return link.queryParameters['token'] ?? input;
    }
    return input;
  }

  Future<void> _editToken() async {
    if (_busy) return;
    var input = await showInput(
      context,
      title: '输入 Mikan Token',
      content: '请输入你的 Token\n（在蜜柑计划的个人中心可以找到）',
      value: _token ?? '',
    );
    if (input == null || input.isEmpty) {
      if (mounted) await BtInfobar.warn(context, '未输入 Token');
      return;
    }
    var parsed = await _parseToken(input);
    if (parsed == _token) {
      if (mounted) await BtInfobar.warn(context, 'Token 未变更');
      return;
    }
    setState(() => _busy = true);
    try {
      await _credential.writeToken(parsed);
      if (!mounted) return;
      setState(() => _token = parsed);
      await BtInfobar.success(context, 'Mikan Token 已保存');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _clearToken() async {
    if (_busy || !_hasToken) return;
    var confirmed = await showConfirmAction(
      context,
      title: '清除 Mikan Token',
      content: '清除后将无法拉取个人订阅 RSS，可随时重新配置。',
      confirmText: '清除',
    );
    if (!mounted || !confirmed) return;
    setState(() => _busy = true);
    try {
      await _credential.deleteToken();
      if (!mounted) return;
      setState(() => _token = null);
      await BtInfobar.success(context, 'Mikan Token 已清除');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
  }) => Tooltip(
    message: label,
    child: Semantics(
      button: true,
      label: label,
      child: SizedBox(
        width: 34,
        height: 34,
        child: IconButton(onPressed: onPressed, icon: Icon(icon, size: 18)),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    var status = !_loaded
        ? '正在读取…'
        : _hasToken
        ? '已配置个人订阅 Token'
        : '未配置，个人订阅 RSS 不可用';
    var enabled = _loaded && !_busy;
    return BTSettingSection(
      icon: FluentIcons.permissions,
      title: '订阅源凭证',
      subtitle: '管理第三方订阅源访问令牌',
      initiallyExpanded: true,
      children: [
        ListTile(
          leading: const BtIcon(FluentIcons.account_management),
          title: const Text('Mikan Token'),
          subtitle: Text(status),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_busy)
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: ProgressRing(strokeWidth: 2),
                  ),
                ),
              _actionButton(
                icon: FluentIcons.edit,
                label: _hasToken ? '编辑 Token' : '设置 Token',
                onPressed: enabled ? _editToken : null,
              ),
              if (_hasToken) ...[
                const SizedBox(width: 4),
                _actionButton(
                  icon: FluentIcons.delete,
                  label: '清除 Token',
                  onPressed: enabled ? _clearToken : null,
                ),
              ],
            ],
          ),
        ),
        const BTSettingHint(
          icon: FluentIcons.info,
          message:
              'Token 用于拉取蜜柑计划个人订阅；'
              '也可在 RSS & BMF 的 Mikan 页通过「打开设置」进入此处。',
        ),
      ],
    );
  }
}
