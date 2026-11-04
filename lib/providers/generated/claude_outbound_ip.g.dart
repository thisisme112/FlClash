// GENERATED CODE - DO NOT MODIFY BY HAND

part of '../claude_outbound_ip.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ClaudeOutboundIpProbe)
final claudeOutboundIpProbeProvider = ClaudeOutboundIpProbeProvider._();

final class ClaudeOutboundIpProbeProvider
    extends
        $NotifierProvider<
          ClaudeOutboundIpProbe,
          RoutedProbeState<String, IpInfo>
        > {
  ClaudeOutboundIpProbeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'claudeOutboundIpProbeProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$claudeOutboundIpProbeHash();

  @$internal
  @override
  ClaudeOutboundIpProbe create() => ClaudeOutboundIpProbe();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RoutedProbeState<String, IpInfo> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RoutedProbeState<String, IpInfo>>(
        value,
      ),
    );
  }
}

String _$claudeOutboundIpProbeHash() =>
    r'7ba56552e1b3ed9e3d191daf0cf766cba8de45f3';

abstract class _$ClaudeOutboundIpProbe
    extends $Notifier<RoutedProbeState<String, IpInfo>> {
  RoutedProbeState<String, IpInfo> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              RoutedProbeState<String, IpInfo>,
              RoutedProbeState<String, IpInfo>
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                RoutedProbeState<String, IpInfo>,
                RoutedProbeState<String, IpInfo>
              >,
              RoutedProbeState<String, IpInfo>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
