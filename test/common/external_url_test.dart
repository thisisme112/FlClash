import 'dart:io';

import 'package:fl_clash/common/external_url.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Windows native association lookup keeps the browser URL separate from its command',
    () async {
      final uri = Uri.parse('https://ip.net.coffee/ip/212.107.30.203');
      final opened = await launchExternalUrl(
        uri,
        windows: true,
        startBrowser: (executable, arguments) async {
          expect(File(executable).existsSync(), isTrue);
          expect(arguments, [uri.toString()]);
        },
        fallback: (target) async {
          expect(target, uri);
          return true;
        },
      );
      expect(opened, isTrue);
    },
    skip: !Platform.isWindows,
  );

  test(
    'Windows passes the HTTPS URL as exactly one browser argument',
    () async {
      final uri = Uri.parse('https://ip.net.coffee/ip/212.107.30.203');
      final calls = <(String, List<String>)>[];
      final opened = await launchExternalUrl(
        uri,
        windows: true,
        browserExecutable: (scheme) {
          expect(scheme, 'https');
          return r'C:\Program Files\Browser\browser.exe';
        },
        startBrowser: (executable, arguments) async {
          calls.add((executable, arguments));
        },
        fallback: (_) async =>
            fail('A valid browser does not need shell activation'),
      );
      expect(opened, isTrue);
      expect(calls.single.$1, r'C:\Program Files\Browser\browser.exe');
      expect(calls.single.$2, ['https://ip.net.coffee/ip/212.107.30.203']);
    },
  );

  test(
    'URL escaping and query separators remain part of the single argument',
    () async {
      final uri = Uri.https('example.com', '/ip/a b', {
        'a': '1&2',
        'b': 'quote"',
      });
      await launchExternalUrl(
        uri,
        windows: true,
        browserExecutable: (_) => 'browser.exe',
        startBrowser: (_, arguments) async =>
            expect(arguments, [uri.toString()]),
      );
    },
  );

  for (final missing in [false, true]) {
    test(
      'Windows falls back when the browser is ${missing ? 'unresolved' : 'unable to start'}',
      () async {
        final uri = Uri.parse('https://ip.net.coffee/ip/212.107.30.203');
        var fallbacks = 0;
        expect(
          await launchExternalUrl(
            uri,
            windows: true,
            browserExecutable: (_) => missing ? null : 'browser.exe',
            startBrowser: (_, _) async =>
                throw const ProcessException('browser.exe', [], 'unavailable'),
            fallback: (target) async {
              fallbacks++;
              expect(target, uri);
              return true;
            },
          ),
          isTrue,
        );
        expect(fallbacks, 1);
      },
    );
  }

  test('other platforms keep their external application handler', () async {
    final uri = Uri.parse('https://ip.net.coffee/ip/212.107.30.203');
    expect(
      await launchExternalUrl(
        uri,
        windows: false,
        browserExecutable: (_) =>
            fail('Windows lookup on a different platform'),
        fallback: (target) async {
          expect(target, uri);
          return false;
        },
      ),
      isFalse,
    );
  });
}
