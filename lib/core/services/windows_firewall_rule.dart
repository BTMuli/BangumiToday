// Dart imports:
import 'dart:convert';
import 'dart:io';

typedef FirewallProcessRunner =
    Future<ProcessResult> Function(String executable, List<String> arguments);

enum EngineFirewallRuleStatus {
  notRegistered,
  registered,
  pathMismatch,
  unsupported,
}

class FirewallRuleException implements Exception {
  FirewallRuleException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// 下载引擎的 Windows 防火墙入站允许规则管理。
///
/// 引擎（bt_download.exe）启动时会监听 TCP/UDP 端口，Windows 防火墙会在首次运行
/// 时弹出“是否允许访问网络”的提示。注册入站允许规则后不再弹窗；引擎更新导致路径
/// 变化时，状态变为 [EngineFirewallRuleStatus.pathMismatch]，需要重新注册。
class WindowsFirewallRuleService {
  WindowsFirewallRuleService({FirewallProcessRunner? processRunner})
    : _processRunner = processRunner ?? _runProcess;

  static final WindowsFirewallRuleService instance =
      WindowsFirewallRuleService();

  static const ruleName = 'BangumiToday bt_download engine';

  final FirewallProcessRunner _processRunner;

  /// 查询引擎路径对应的防火墙规则状态。
  Future<EngineFirewallRuleStatus> status(String enginePath) async {
    if (!Platform.isWindows) return EngineFirewallRuleStatus.unsupported;
    var result = await _processRunner('powershell.exe', [
      '-NoProfile',
      '-NonInteractive',
      '-Command',
      _statusScript(enginePath),
    ]);
    switch (result.stdout.trim()) {
      case 'MATCH':
        return EngineFirewallRuleStatus.registered;
      case 'MISMATCH':
        return EngineFirewallRuleStatus.pathMismatch;
      default:
        return EngineFirewallRuleStatus.notRegistered;
    }
  }

  /// 注册或更新引擎路径的入站允许规则，需要用户确认管理员授权。
  Future<void> register(String enginePath) async {
    if (!Platform.isWindows) {
      throw FirewallRuleException('仅支持在 Windows 上注册防火墙规则');
    }
    await _runElevated(_registerScript(enginePath));
    if (await status(enginePath) != EngineFirewallRuleStatus.registered) {
      throw FirewallRuleException('规则未生效，可能未完成管理员授权');
    }
  }

  /// 移除已注册的防火墙规则，需要用户确认管理员授权。
  Future<void> unregister(String enginePath) async {
    if (!Platform.isWindows) {
      throw FirewallRuleException('仅支持在 Windows 上管理防火墙规则');
    }
    await _runElevated(_unregisterScript());
    if (await status(enginePath) != EngineFirewallRuleStatus.notRegistered) {
      throw FirewallRuleException('规则仍存在，可能未完成管理员授权');
    }
  }

  Future<void> _runElevated(String script) async {
    var encoded = _encodeCommand(script);
    var result = await _processRunner('powershell.exe', [
      '-NoProfile',
      '-NonInteractive',
      '-WindowStyle',
      'Hidden',
      '-Command',
      "Start-Process -FilePath powershell.exe -Verb RunAs "
          "-WindowStyle Hidden -Wait -ArgumentList @('-NoProfile', "
          "'-NonInteractive', '-EncodedCommand', '$encoded')",
    ]);
    if (result.exitCode != 0) {
      throw FirewallRuleException('管理员授权未完成（已取消或失败）');
    }
  }

  String _statusScript(String enginePath) {
    var quotedPath = _quote(enginePath);
    return [
      "\$rule = Get-NetFirewallRule -DisplayName '$ruleName' "
          '-ErrorAction SilentlyContinue',
      "if (\$null -eq \$rule) { Write-Output 'NOT_FOUND'; exit 0 }",
      '\$program = (Get-NetFirewallApplicationFilter '
          '-AssociatedNetFirewallRule \$rule '
          '| Select-Object -First 1).Program',
      "if ([string]::IsNullOrWhiteSpace(\$program)) "
          "{ Write-Output 'MISMATCH'; exit 0 }",
      "if (\$program -eq $quotedPath) "
          "{ Write-Output 'MATCH' } else { Write-Output 'MISMATCH' }",
    ].join('\n');
  }

  String _registerScript(String enginePath) {
    var quotedPath = _quote(enginePath);
    return [
      "\$ErrorActionPreference = 'Stop'",
      "Get-NetFirewallRule -DisplayName '$ruleName' "
          '-ErrorAction SilentlyContinue '
          '| Remove-NetFirewallRule -ErrorAction SilentlyContinue',
      "New-NetFirewallRule -DisplayName '$ruleName' -Direction Inbound "
          "-Action Allow -Program $quotedPath -Profile Any | Out-Null",
      "Write-Output 'OK'",
    ].join('\n');
  }

  String _unregisterScript() {
    return [
      "\$ErrorActionPreference = 'Stop'",
      "Get-NetFirewallRule -DisplayName '$ruleName' "
          '-ErrorAction SilentlyContinue '
          '| Remove-NetFirewallRule -ErrorAction SilentlyContinue',
      "Write-Output 'OK'",
    ].join('\n');
  }

  String _quote(String value) => "'${value.replaceAll("'", "''")}'";

  String _encodeCommand(String script) {
    var bytes = <int>[];
    for (var unit in script.codeUnits) {
      bytes.add(unit & 0xff);
      bytes.add((unit >> 8) & 0xff);
    }
    return base64Encode(bytes);
  }

  static Future<ProcessResult> _runProcess(
    String executable,
    List<String> arguments,
  ) {
    return Process.run(executable, arguments);
  }
}
