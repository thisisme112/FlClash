import 'package:fl_clash/common/service_probe.dart';
import 'package:fl_clash/core/controller.dart';
import 'package:fl_clash/core/interface.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/claude_outbound_ip.dart';
import 'package:fl_clash/providers/core.dart';
import 'package:fl_clash/providers/route_state.dart';
import 'package:fl_clash/providers/routed_probe.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/riverpod.dart';

class _MockCore extends Mock implements CoreHandlerInterface {}

const _answer = OutboundIpResult(
  url: claudeTraceUrl,
  body: 'ip=203.0.113.44\nloc=US\n',
  chains: ['Claude exit'],
  coreEpoch: 1,
  routeVersion: 2,
  hits: [RouteHit(host: 'claude.ai:443', exit: 'Claude exit')],
);

void main() {
  setUpAll(() => registerFallbackValue(const OutboundIpParams(timeout: 0)));
  late _MockCore core;
  setUp(() => core = _MockCore());

  ProviderContainer build({bool proxied = true}) {
    final container = ProviderContainer(
      overrides: [
        routeTrackerProvider.overrideWithBuild(
          (_, _) => RouteState(
            coreEpoch: 1,
            routeVersion: 2,
            hostEpoch: 1,
            proxied: proxied,
            synced: true,
            live: true,
          ),
        ),
        coreHandlerProvider.overrideWithValue(CoreController.scoped(core)),
      ],
    );
    addTearDown(container.dispose);
    container.listen(claudeOutboundIpProbeProvider, (_, _) {});
    return container;
  }

  test(
    'probes only the Claude trace through current rules and preserves its route stamp',
    () async {
      when(() => core.outboundIp(any())).thenAnswer((_) async => _answer);
      final container = build();
      container
          .read(claudeOutboundIpProbeProvider.notifier)
          .watch(routedOutbound);
      await pumpEventQueue();
      final params =
          verify(() => core.outboundIp(captureAny())).captured.single
              as OutboundIpParams;
      expect(params.urls, [claudeTraceUrl]);
      expect(params.proxyName, routedOutbound);
      final state = container.read(claudeOutboundIpProbeProvider);
      expect(state.valueOf(routedOutbound)?.ip, '203.0.113.44');
      expect(state.entryOf(routedOutbound).stamp?.hits, _answer.hits);
      expect(state.entryOf(routedOutbound).stamp?.routeVersion, 2);
      expect(state.entries.keys, [routedOutbound]);
    },
  );

  test('pins DIRECT when the proxy is off', () async {
    when(() => core.outboundIp(any())).thenAnswer((_) async => _answer);
    final container = build(proxied: false);
    container
        .read(claudeOutboundIpProbeProvider.notifier)
        .watch(routedOutbound);
    await pumpEventQueue();
    final params =
        verify(() => core.outboundIp(captureAny())).captured.single
            as OutboundIpParams;
    expect(params.proxyName, directOutbound);
  });

  for (final answer in [
    _answer.copyWith(error: 'timeout'),
    _answer.copyWith(url: 'https://www.cloudflare.com/cdn-cgi/trace'),
    _answer.copyWith(body: '<html>challenge</html>'),
    _answer.copyWith(body: 'ip=not-an-ip\nloc=US'),
  ]) {
    test(
      'a failed or mismatched Claude trace has no scoreable exit: ${answer.url} ${answer.body}',
      () async {
        when(() => core.outboundIp(any())).thenAnswer((_) async => answer);
        final container = build();
        container
            .read(claudeOutboundIpProbeProvider.notifier)
            .watch(routedOutbound);
        await pumpEventQueue();
        final entry = container
            .read(claudeOutboundIpProbeProvider)
            .entryOf(routedOutbound);
        expect(entry.phase, ProbePhase.failed);
        expect(entry.value, isNull);
      },
    );
  }

  test('Claude trace accepts IPv6 exits', () {
    expect(
      parseClaudeOutboundIp(
        _answer.copyWith(body: 'ip=2001:db8::1\nloc=JP'),
      )?.ip,
      '2001:db8::1',
    );
  });
}
