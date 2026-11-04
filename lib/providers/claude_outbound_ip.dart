import 'package:fl_clash/common/constant.dart';
import 'package:fl_clash/common/service_probe.dart';
import 'package:fl_clash/models/models.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'core.dart';
import 'route_state.dart';
import 'routed_probe.dart';

part 'generated/claude_outbound_ip.g.dart';

@Riverpod(keepAlive: true)
class ClaudeOutboundIpProbe extends _$ClaudeOutboundIpProbe
    with RoutedProbe<String, IpInfo> {
  @override
  RoutedProbeState<String, IpInfo> build() => buildProbe();

  @override
  Future<Map<String, ProbeAnswer<IpInfo>>> probe(
    String target,
    RouteState route,
  ) async {
    final result = await ref
        .read(coreHandlerProvider)
        .outboundIp(
          OutboundIpParams(
            proxyName: route.proxied ? routedOutbound : directOutbound,
            urls: const [claudeTraceUrl],
            timeout: outboundIpTimeoutDuration.inMilliseconds,
          ),
        );
    return {
      target: ProbeAnswer(
        value: parseClaudeOutboundIp(result),
        coreEpoch: result.coreEpoch,
        routeVersion: result.routeVersion,
        hits: result.hits,
      ),
    };
  }
}
