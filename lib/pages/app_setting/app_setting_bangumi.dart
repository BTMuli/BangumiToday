// Package imports:
import 'package:cached_network_image/cached_network_image.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Project imports:
import '../../controller/progress_controller.dart';
import '../../core/services/bangumi_oauth_coordinator.dart';
import '../../core/services/bangumi_token_service.dart';
import '../../models/app/bangumi_mirror.dart';
import '../../models/bangumi/bangumi_enum.dart';
import '../../models/bangumi/bangumi_oauth_model.dart';
import '../../providers/app_providers.dart';
import '../../request/bangumi/bangumi_api.dart';
import '../../request/bangumi/bangumi_oauth.dart';
import '../../store/app_store.dart' as app_store;
import '../../tools/log_tool.dart';
import '../../ui/bt_dialog.dart';
import '../../ui/bt_icon.dart';
import '../../ui/bt_infobar.dart';
import '../../ui/bt_select.dart';
import '../../widgets/common/bt_buttons.dart';
import '../../widgets/common/bt_setting_section.dart';
import 'bangumi_mirror_dialog.dart';

/// 设置页BangumiUserInfo
class AppConfigBgmWidget extends ConsumerStatefulWidget {
  /// 构造函数
  const AppConfigBgmWidget({super.key});

  @override
  ConsumerState<AppConfigBgmWidget> createState() => _AppConfigBgmWidgetState();
}

class _AppConfigBgmWidgetState extends ConsumerState<AppConfigBgmWidget> {
  /// 当前登录用户
  BgmUserState get _user => ref.watch(bgmUserStoreProvider);

  /// 认证相关客户端
  final BtrBangumiOauth apiOauth = BtrBangumiOauth();

  /// 进度条
  late ProgressController progress = ProgressController();

  /// 是否正在刷新授权
  bool _refreshingAuth = false;

  bool _isLoggingIn = false;

  String? _mirrorAction;

  @override
  void dispose() {
    if (_isLoggingIn) BangumiOAuthCoordinator.instance.cancel();
    apiOauth.client.dispose();
    super.dispose();
  }

  /// 刷新用户信息
  Future<void> freshUserInfo() async {
    if (progress.isShow) {
      progress.update(title: '获取用户信息', text: '正在获取用户信息', progress: null);
    } else {
      progress = ProgressWidget.show(context, title: '获取用户信息');
    }
    if (_user.accessToken == null) {
      progress.end();
      if (mounted) await BtInfobar.error(context, '未找到访问令牌');
      return;
    }
    var repository = ref.read(bangumiRepositoryProvider);
    var userResp = await repository.getUserInfo();
    if (userResp.code != 0 || userResp.data == null) {
      progress.end();
      if (mounted) await showRespErr(userResp, context);
      return;
    }
    await ref.read(bgmUserStoreProvider.notifier).updateUser(userResp.data!);
    if (!mounted) {
      progress.end();
      return;
    }
    progress.update(title: '获取用户信息成功', text: '用户信息：${_user.user!.nickname}');
    progress.end();
    if (mounted) {
      await BtInfobar.success(
        context,
        '成功获取[${_user.user!.id}]${_user.user!.nickname}信息',
      );
    }
  }

  /// 是否已有可用于刷新的 refresh token
  bool get _canRefreshAuth {
    var token = _user.refreshToken;
    return token != null && token.isNotEmpty;
  }

  /// 刷新授权
  Future<void> refreshAuth() async {
    if (_refreshingAuth) return;
    if (!_canRefreshAuth) {
      if (mounted) {
        await BtInfobar.error(context, '未找到刷新令牌，无法刷新授权');
      }
      return;
    }
    setState(() => _refreshingAuth = true);
    var result = await BangumiTokenService.instance.ensureFresh(force: true);
    if (!mounted) return;
    setState(() => _refreshingAuth = false);
    switch (result) {
      case BangumiTokenRefreshResult.notNeeded:
        await BtInfobar.info(context, '授权未过期，无需刷新');
      case BangumiTokenRefreshResult.refreshed:
        await BtInfobar.success(context, '授权刷新成功');
      case BangumiTokenRefreshResult.unavailable:
        await BtInfobar.error(context, '未找到刷新令牌，无法刷新授权');
      case BangumiTokenRefreshResult.failed:
        await BtInfobar.error(context, '授权刷新失败');
    }
  }

  /// 认证用户
  Future<void> oauthUser() async {
    var coordinator = BangumiOAuthCoordinator.instance;
    if (_isLoggingIn || coordinator.isAuthorizing || progress.isShow) return;
    _isLoggingIn = true;
    var authProgress = ProgressWidget.show(
      context,
      title: 'Bangumi 授权',
      text: '正在打开浏览器授权页面',
      onCancel: coordinator.cancel,
      cancelText: '取消授权',
    );
    progress = authProgress;
    try {
      var res = await coordinator.authorize(
        apiOauth,
        onProgress: (text) => authProgress.update(text: text),
      );
      if (!mounted || res.code == 499) return;
      if (res.code != 0 || res.data == null) {
        authProgress.end();
        await showRespErr(res, context);
        return;
      }
      authProgress.onCancel = null;
      authProgress.update(text: '保存授权信息');
      var at = res.data as BangumiOauthTokenGetData;
      await ref
          .read(bgmUserStoreProvider.notifier)
          .updateTokenSet(
            newSession: true,
            accessToken: at.accessToken,
            refreshToken: at.refreshToken,
            expiresIn: at.expiresIn,
          );
      if (mounted) await freshUserInfo();
    } catch (error) {
      BTLogTool.error('用户授权失败：$error');
      authProgress.end();
      if (mounted) await BtInfobar.error(context, '授权失败，请重试');
    } finally {
      authProgress.end();
      _isLoggingIn = false;
    }
  }

  /// 尝试删除用户信息
  Future<void> tryDeleteUserInfo() async {
    if (_user.user == null) {
      await BtInfobar.error(context, '未找到用户信息');
      return;
    }
    var deleteConfirm = await showConfirm(
      context,
      title: '删除用户信息',
      content: '是否删除用户信息？',
    );
    if (!deleteConfirm) return;
    await ref.read(bgmUserStoreProvider.notifier).deleteUser();
    if (mounted) setState(() {});
  }

  /// 构建用户信息与授权信息（合并展示）
  Widget buildUserAuth() {
    var user = _user.user;
    Widget leading;
    if (user == null) {
      leading = const BtIcon(FluentIcons.user_sync);
    } else {
      leading = Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: FluentTheme.of(context).accentColor.withValues(alpha: 0.4),
            width: 1.5,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: CachedNetworkImage(
          imageUrl: BtrBangumiApi.rewriteUrl(user.avatar.small),
          width: 32,
          height: 32,
          fit: BoxFit.cover,
          placeholder: (_, _) => const ProgressRing(),
          errorWidget: (_, _, _) => const Icon(FluentIcons.error),
        ),
      );
    }
    return ListTile(
      leading: leading,
      title: Text(user?.nickname ?? '未找到用户信息'),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (user != null) Text('ID: ${user.id}(${user.userGroup.label})'),
          Text(
            _user.expireTime == null ? '未找到授权信息' : '授权过期时间：${_user.expireTime}',
          ),
          const Text('账号授权始终使用官方服务'),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (user != null) ...[
            BTIconButton(
              icon: FluentIcons.delete,
              tooltip: '删除用户',
              onPressed: tryDeleteUserInfo,
            ),
            SizedBox(width: 8),
          ],
          if (_canRefreshAuth) ...[
            Button(
              onPressed: _refreshingAuth ? null : refreshAuth,
              child: Text(_refreshingAuth ? '刷新中…' : '刷新授权'),
            ),
            SizedBox(width: 8),
          ],
          FilledButton(
            onPressed: oauthUser,
            child: Text(user == null ? '前往授权' : '重新授权'),
          ),
        ],
      ),
    );
  }

  /// 分别配置网页、API 与图片镜像。
  Widget buildMirror() {
    var settings = ref.watch(app_store.appStoreProvider);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var type in BangumiMirrorType.values)
          _buildMirrorSetting(type, settings),
      ],
    );
  }

  Widget _buildMirrorSetting(
    BangumiMirrorType type,
    app_store.BTAppSettings settings,
  ) {
    var value = settings.bangumiMirrorUrl(type);
    var catalog = settings.bangumiMirrorCatalog;
    var custom = catalog.entries(type);
    var selected = custom.where((mirror) => mirror.url == value).firstOrNull;
    var enabled = settings.loaded && _mirrorAction == null;
    var choices = [...type.builtIns, ...custom];
    if (!choices.any((mirror) => mirror.url == value)) {
      choices.add(BangumiMirror(name: value, url: value));
    }
    return ListTile(
      leading: const BtIcon(FluentIcons.globe),
      title: Text(type.label),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value),
          const SizedBox(height: 8),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 190,
                child: BtSelect<String>(
                  value: value,
                  isExpanded: true,
                  items: [
                    for (var mirror in choices)
                      ComboBoxItem(
                        value: mirror.url,
                        child: Text(
                          mirror.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: !enabled
                      ? null
                      : (url) async {
                          if (url == null || url == value) return;
                          await _changeMirror(
                            '${type.name}:select',
                            () => ref
                                .read(app_store.appStoreProvider.notifier)
                                .setBangumiMirror(type, url),
                          );
                        },
                ),
              ),
              _mirrorActionButton(
                '${type.name}:add',
                icon: FluentIcons.add,
                label: '新增${type.label}',
                onPressed: enabled ? () => _editMirror(type) : null,
              ),
              _mirrorActionButton(
                '${type.name}:edit',
                icon: FluentIcons.edit,
                label: selected == null ? '内置镜像不能编辑' : '编辑${type.label}',
                onPressed: enabled && selected != null
                    ? () => _editMirror(type, mirror: selected)
                    : null,
              ),
              _mirrorActionButton(
                '${type.name}:delete',
                icon: FluentIcons.delete,
                label: selected == null ? '内置镜像不能删除' : '删除${type.label}',
                onPressed: enabled && selected != null
                    ? () => _deleteMirror(type, selected)
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _mirrorActionButton(
    String action, {
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
  }) => Tooltip(
    message: _mirrorAction == action ? '正在保存镜像' : label,
    child: Semantics(
      button: true,
      label: label,
      child: SizedBox(
        width: 34,
        height: 34,
        child: IconButton(
          onPressed: onPressed,
          icon: _mirrorAction == action
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: ProgressRing(strokeWidth: 2),
                )
              : Icon(icon, size: 18),
        ),
      ),
    ),
  );

  Future<void> _changeMirror(
    String action,
    Future<void> Function() save,
  ) async {
    if (_mirrorAction != null) return;
    setState(() => _mirrorAction = action);
    try {
      await save();
      if (mounted) await BtInfobar.success(context, '镜像设置已更新');
    } on FormatException catch (error) {
      if (mounted) await BtInfobar.error(context, error.message);
    } catch (error) {
      BTLogTool.error('保存 Bangumi 镜像失败：$error');
      if (mounted) await BtInfobar.error(context, '保存镜像失败，请重试');
    } finally {
      if (mounted) setState(() => _mirrorAction = null);
    }
  }

  Future<void> _editMirror(
    BangumiMirrorType type, {
    BangumiMirror? mirror,
  }) async {
    var result = await showBangumiMirrorDialog(
      context,
      type: type,
      catalog: ref.read(app_store.appStoreProvider).bangumiMirrorCatalog,
      mirror: mirror,
    );
    if (!mounted || result == null) return;
    await _changeMirror(
      '${type.name}:${mirror == null ? 'add' : 'edit'}',
      () => ref
          .read(app_store.appStoreProvider.notifier)
          .saveBangumiMirror(type, result, originalUrl: mirror?.url),
    );
  }

  Future<void> _deleteMirror(
    BangumiMirrorType type,
    BangumiMirror mirror,
  ) async {
    var confirmed = await showConfirmAction(
      context,
      title: '删除${type.label}',
      content: '删除“${mirror.name}”后将恢复该类别的默认镜像。',
      confirmText: '删除',
    );
    if (!mounted || !confirmed) return;
    await _changeMirror(
      '${type.name}:delete',
      () => ref
          .read(app_store.appStoreProvider.notifier)
          .deleteBangumiMirror(type, mirror.url),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BTSettingSection(
      icon: FluentIcons.user_window,
      title: 'Bangumi 配置',
      subtitle: '账号授权与镜像站设置',
      initiallyExpanded: false,
      children: [buildMirror(), const BTSettingDivider(), buildUserAuth()],
    );
  }
}
