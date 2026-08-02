// Dart imports:
import 'dart:convert';
import 'dart:io';

// Package imports:
import 'package:bangumi_today/core/services/windows_firewall_rule.dart';
import 'package:flutter_test/flutter_test.dart';

const _ruleName = 'BangumiToday bt_download engine';

String _decodeEncodedCommand(String encoded) {
  var bytes = base64Decode(encoded);
  var units = <int>[];
  for (var i = 0; i + 1 < bytes.length; i += 2) {
    units.add(bytes[i] | (bytes[i + 1] << 8));
  }
  return String.fromCharCodes(units);
}

String _encodedOf(List<String> arguments) {
  var match = RegExp(
    r"'-EncodedCommand', '([^']+)'",
  ).firstMatch(arguments.last)!;
  return match.group(1)!;
}

void main() {
  group('WindowsFirewallRuleService', () {
    var calls = <(String, List<String>)>[];

    WindowsFirewallRuleService serviceWith(
      List<String> outputs, {
      List<int> exitCodes = const [],
    }) {
      calls = [];
      var callIndex = 0;
      return WindowsFirewallRuleService(
        processRunner: (executable, arguments) async {
          calls.add((executable, arguments));
          var index = callIndex++;
          var output = outputs[index % outputs.length];
          var exitCode = exitCodes.isEmpty
              ? 0
              : exitCodes[index < exitCodes.length
                    ? index
                    : exitCodes.length - 1];
          return ProcessResult(0, exitCode, output, '');
        },
      );
    }

    test('reports registered when the rule path matches', () async {
      var service = serviceWith(['MATCH']);

      expect(
        await service.status(r'C:\app\bt_download\bt_download.exe'),
        EngineFirewallRuleStatus.registered,
      );
      expect(calls.single.$1, 'powershell.exe');
      expect(calls.single.$2.join(' '), contains(_ruleName));
      expect(calls.single.$2.join(' '), contains('NOT_FOUND'));
    });

    test('reports path mismatch when the rule points elsewhere', () async {
      var service = serviceWith(['MISMATCH']);

      expect(
        await service.status(r'C:\new\bt_download.exe'),
        EngineFirewallRuleStatus.pathMismatch,
      );
    });

    test('reports not registered when no rule exists', () async {
      var service = serviceWith(['NOT_FOUND']);

      expect(
        await service.status(r'C:\app\bt_download\bt_download.exe'),
        EngineFirewallRuleStatus.notRegistered,
      );
    });

    test('register runs an elevated script and verifies the rule', () async {
      var service = serviceWith(['MATCH'], exitCodes: [0]);
      var enginePath = r'C:\app\bt_download\bt_download.exe';

      await service.register(enginePath);

      expect(calls, hasLength(2));
      var elevated = calls.first.$2;
      expect(calls.first.$1, 'powershell.exe');
      expect(elevated.join(' '), contains('-Verb RunAs'));
      expect(elevated.join(' '), contains('Start-Process'));
      expect(elevated.join(' '), contains('-EncodedCommand'));
      var script = _decodeEncodedCommand(_encodedOf(elevated));
      expect(script, contains(_ruleName));
      expect(script, contains("'C:\\app\\bt_download\\bt_download.exe'"));
      expect(script, contains('-Direction Inbound -Action Allow'));
      expect(calls.last.$2.join(' '), contains(_ruleName));
    });

    test('register escapes single quotes in the engine path', () async {
      var service = serviceWith(['MATCH'], exitCodes: [0]);

      await service.register(r"C:\a'b\bt_download.exe");

      var script = _decodeEncodedCommand(_encodedOf(calls.first.$2));
      expect(script, contains("'C:\\a''b\\bt_download.exe'"));
    });

    test('register throws when elevation is canceled', () async {
      var service = serviceWith([''], exitCodes: [1]);

      await expectLater(
        service.register(r'C:\app\bt_download\bt_download.exe'),
        throwsA(isA<FirewallRuleException>()),
      );
      expect(calls, hasLength(1));
    });

    test('register throws when the rule is not applied', () async {
      var service = serviceWith(['NOT_FOUND'], exitCodes: [0]);

      await expectLater(
        service.register(r'C:\app\bt_download\bt_download.exe'),
        throwsA(isA<FirewallRuleException>()),
      );
      expect(calls, hasLength(2));
    });

    test('unregister runs an elevated script and verifies removal', () async {
      var service = serviceWith(['', 'NOT_FOUND'], exitCodes: [0]);

      await service.unregister(r'C:\app\bt_download\bt_download.exe');

      expect(calls, hasLength(2));
      expect(calls.first.$2.join(' '), contains('-Verb RunAs'));
      var script = _decodeEncodedCommand(_encodedOf(calls.first.$2));
      expect(script, contains('Remove-NetFirewallRule'));
      expect(script, contains(_ruleName));
    });

    test('unregister throws when the rule still exists', () async {
      var service = serviceWith(['', 'MATCH'], exitCodes: [0]);

      await expectLater(
        service.unregister(r'C:\app\bt_download\bt_download.exe'),
        throwsA(isA<FirewallRuleException>()),
      );
      expect(calls, hasLength(2));
    });
  });
}
