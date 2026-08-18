// Dart imports:
import 'dart:io';

// Package imports:
import 'package:flutter_test/flutter_test.dart';

// Project imports:
import 'package:bangumi_today/core/services/windows_app_protocol.dart';

const _backupKey = r'HKCU\Software\BangumiToday\DevProtocolHijack';
const _appXCommand = r'HKCU\Software\Classes\AppXabc\Shell\open\command';

void main() {
  group('WindowsAppProtocol', () {
    late Map<String, Map<String, String>> reg;

    WindowsAppProtocol build({
      String exe = r'D:\dev\bangumi_today.exe',
      String? progId = 'AppXabc',
    }) {
      reg = {};
      return WindowsAppProtocol(
        isWindows: true,
        executable: () => exe,
        protocolProgId: (_) => progId,
        notifyAssocChanged: () {},
        runProcess: (executable, arguments) async {
          expect(executable, 'reg');
          return _fakeReg(reg, arguments);
        },
      );
    }

    test('takes over an AppX protocol handler', () async {
      var protocol = build();
      reg[_appXCommand] = {'DelegateExecute': '{CLSID}'};

      await protocol.register();

      expect(reg[_appXCommand]![''], contains(r'D:\dev\bangumi_today.exe'));
      expect(reg[_appXCommand]!.containsKey('DelegateExecute'), isFalse);
      expect(reg[_backupKey]!['ProgId'], 'AppXabc');
      expect(reg[_backupKey]!['DelegateExecute'], '{CLSID}');
    });

    test('restores DelegateExecute when leaving unpackaged mode', () async {
      var protocol = build();
      reg[_appXCommand] = {'DelegateExecute': '{CLSID}'};

      await protocol.register();
      await protocol.restore();

      expect(reg[_appXCommand]!['DelegateExecute'], '{CLSID}');
      expect(reg[_appXCommand]!.containsKey(''), isFalse);
      expect(reg.containsKey(_backupKey), isFalse);
    });

    test('keeps the original DelegateExecute across re-register', () async {
      var protocol = build();
      reg[_appXCommand] = {'DelegateExecute': '{ORIGINAL}'};

      await protocol.register();
      await protocol.register();

      expect(reg[_backupKey]!['DelegateExecute'], '{ORIGINAL}');
    });

    test('does not take over a packaged WindowsApps executable', () async {
      var protocol = build(
        exe: r'C:\Program Files\WindowsApps\BangumiToday\app.exe',
      );

      await protocol.register();
      expect(reg, isEmpty);
    });

    test('skips AppX takeover when no packaged handler exists', () async {
      var protocol = build(progId: 'bangumitoday');
      reg[_appXCommand] = {'DelegateExecute': '{CLSID}'};

      await protocol.register();

      expect(reg[_appXCommand]!['DelegateExecute'], '{CLSID}');
      expect(reg.containsKey(_backupKey), isFalse);
    });
  });
}

ProcessResult _fakeReg(
  Map<String, Map<String, String>> reg,
  List<String> args,
) {
  var action = args.first;
  var key = args[1];
  switch (action) {
    case 'add':
      var name = '';
      var value = '';
      for (var i = 2; i < args.length; i++) {
        if (args[i] == '/v') {
          name = args[++i];
        } else if (args[i] == '/d') {
          value = args[++i];
        }
      }
      (reg[key] ??= {})[name] = value;
      return ProcessResult(0, 0, '', '');
    case 'query':
      var name = '';
      for (var i = 2; i < args.length; i++) {
        if (args[i] == '/v') name = args[++i];
      }
      var values = reg[key];
      if (values == null || !values.containsKey(name)) {
        return ProcessResult(0, 1, '', 'not found');
      }
      return ProcessResult(
        0,
        0,
        '    $name    REG_SZ    ${values[name]}\r\n',
        '',
      );
    case 'delete':
      if (args.contains('/ve')) {
        reg[key]?.remove('');
      } else if (args.contains('/v')) {
        var name = args[args.indexOf('/v') + 1];
        reg[key]?.remove(name);
      } else {
        reg.remove(key);
      }
      return ProcessResult(0, 0, '', '');
    default:
      return ProcessResult(0, 1, '', 'unknown');
  }
}
