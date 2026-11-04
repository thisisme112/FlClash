import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/service_probe.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/features/ip_quality/ip_quality.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/outbound_ip.dart';
import 'package:fl_clash/providers/claude_outbound_ip.dart';
import 'package:fl_clash/providers/ip_quality.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/providers/routed_probe.dart';
import 'package:fl_clash/providers/service_status.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'route_flow.dart';
import 'network_panel.dart';
import 'network_controls.dart';
import 'widgets/proxy_groups.dart' show showProxiesSheet;
import 'widgets/service_status.dart' show showServiceStatusSheet;

const _rowHeight = 78.0;
const _engineWidth = 156.0;
const _wireWidth = 40.0;

class NetworkPathView extends ConsumerStatefulWidget {
  const NetworkPathView({super.key, this.platform});

  final SupportPlatform? platform;

  @override
  ConsumerState<NetworkPathView> createState() => _NetworkPathViewState();
}

class _NetworkPathViewState extends ConsumerState<NetworkPathView> {
  late final ServiceStatus _services;
  late final OutboundIpProbe _outbounds;
  late final ClaudeOutboundIpProbe _claude;
  bool _claudeWatched = false;
  bool _paused = false;
  Set<ServiceTarget> _targets = {};
  Set<String> _exits = {routedOutbound};

  @override
  void initState() {
    super.initState();
    _services = ref.read(serviceStatusProvider.notifier);
    _claude = ref.read(claudeOutboundIpProbeProvider.notifier);
    _outbounds = ref.read(outboundIpProbeProvider.notifier)
      ..watch(routedOutbound);
  }

  void _sync(
    List<ServiceTarget> targets,
    Set<String> exits,
    bool claudeEnabled,
  ) {
    if (_claudeWatched != claudeEnabled) {
      if (claudeEnabled) {
        _claude.watch(routedOutbound);
      } else {
        _claude.unwatch(routedOutbound);
      }
      _claudeWatched = claudeEnabled;
    }
    final next = targets.toSet();
    if (next.length != _targets.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(shownServiceCountProvider.notifier).value = next.length;
        }
      });
    }
    for (final target in next.difference(_targets)) {
      _services.watch(target);
    }
    for (final target in _targets.difference(next)) {
      _services.unwatch(target);
    }
    for (final exit in exits.difference(_exits)) {
      _outbounds.watch(exit);
    }
    for (final exit in _exits.difference(exits)) {
      _outbounds.unwatch(exit);
    }
    _targets = next;
    _exits = exits;
  }

  @override
  void dispose() {
    for (final target in _targets) {
      _services.unwatch(target);
    }
    for (final exit in _exits) {
      _outbounds.unwatch(exit);
    }
    if (_claudeWatched) _claude.unwatch(routedOutbound);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabledTargets = ref.watch(enabledServiceTargetsProvider);
    final targets = enabledTargets.take(6).toList();
    final claudeEnabled = enabledTargets.contains(ServiceTarget.claude);
    final claudeExits = ref.watch(claudeOutboundIpProbeProvider);
    final claudeExit = claudeExits.valueOf(routedOutbound);
    final moving =
        !_paused &&
        ref.watch(isStartProvider) &&
        !ref.watch(suspendProvider) &&
        ref.watch(appVisibleProvider);
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    final services = ref.watch(serviceStatusProvider);
    final outbounds = ref.watch(outboundIpProbeProvider);
    final nodes = <String>{
      routedOutbound,
      for (final target in targets) ?services.valueOf(target)?.node,
    };
    _sync(targets, nodes, claudeEnabled);
    final busy =
        targets.any(services.isLoading) ||
        nodes.any(outbounds.isLoading) ||
        (claudeEnabled && claudeExits.isLoading(routedOutbound));
    final ip = outbounds.valueOf(routedOutbound)?.ip;
    final colors = context.colorScheme;
    final localizations = context.appLocalizations;
    IpInfo? exitOf(ServiceTarget target) {
      if (target == ServiceTarget.claude) return claudeExit;
      final node = services.valueOf(target)?.node;
      return node == null ? null : outbounds.valueOf(node);
    }

    void refresh() {
      _services.refresh(targets);
      _outbounds.refresh(nodes);
      if (claudeEnabled) {
        _claude.refresh([routedOutbound]);
        if (claudeExit?.ip case final address? when address != ip) {
          ref.invalidate(ipQualityProvider(address));
        }
      }
      if (ip != null) ref.invalidate(ipQualityProvider(ip));
    }

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        context.contentTopPadding + 12,
        20,
        24 + context.bottomInset,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            spacing: 12,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 5,
                  children: [
                    Text(
                      appName,
                      style: AppTextStyle.title2.of(context, emphasized: true),
                    ),
                    Text(
                      localizations.networkPathHint,
                      style: AppTextStyle.caption1
                          .of(context)
                          .copyWith(color: colors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: localizations.quickSwitchProxy,
                onPressed: () => showProxiesSheet(context),
                icon: const GlyphIcon(AppGlyphs.proxies),
              ),
              IconButton(
                tooltip: _paused
                    ? localizations.resumePathAnimation
                    : localizations.pausePathAnimation,
                onPressed: reducedMotion
                    ? null
                    : () => setState(() => _paused = !_paused),
                icon: GlyphIcon(
                  AppGlyphs.playPause(_paused || reducedMotion ? 0 : 1),
                ),
              ),
              IconButton(
                tooltip: localizations.ipQualityRetry,
                onPressed: busy ? null : refresh,
                icon: const GlyphIcon(AppGlyphs.refresh),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const NetworkProxySwitch(),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 900;
              final quality = NetworkPanel(child: IpQualitySummary(ip: ip));
              final claudeQuality = NetworkPanel(
                child: IpQualitySummary(
                  ip: claudeExit?.ip,
                  claude: true,
                  exitLoading: claudeExits.isLoading(routedOutbound),
                  exitFailed:
                      claudeExits.entryOf(routedOutbound).phase ==
                      ProbePhase.failed,
                ),
              );
              final flowRoutes = [
                for (final (index, target) in targets.indexed)
                  (
                    _routeColor(context, index),
                    services.entryOf(target).phase == ProbePhase.fresh &&
                        services.valueOf(target)?.status ==
                            ServiceProbeStatus.available,
                  ),
              ];
              const entry = _EntryNode();
              final routes = [
                for (final (index, target) in targets.indexed)
                  _ServiceRoute(
                    target: target,
                    entry: services.entryOf(target),
                    ip: exitOf(target),
                    color: _routeColor(context, index),
                    onTap: () => showServiceStatusSheet(context),
                  ),
              ];
              if (!wide) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 16,
                  children: [
                    quality,
                    if (claudeEnabled) claudeQuality,
                    entry,
                    const _EngineNode(compact: true),
                    const _LiveTraffic(),
                    Text(
                      localizations.serviceStatus,
                      style: AppTextStyle.headline.of(context),
                    ),
                    NetworkRouteFlow(
                      routes: flowRoutes,
                      animate: moving,
                      vertical: true,
                      child: Padding(
                        padding: const EdgeInsetsDirectional.only(start: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          spacing: 10,
                          children: routes,
                        ),
                      ),
                    ),
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                spacing: 24,
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: 18,
                      children: [
                        quality,
                        entry,
                        const _LiveTraffic(),
                        if (claudeEnabled) claudeQuality,
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 6,
                    child: NetworkRouteFlow(
                      routes: flowRoutes,
                      animate: moving,
                      engineWidth: _engineWidth,
                      wireWidth: _wireWidth,
                      child: Row(
                        children: [
                          const SizedBox(
                            width: _engineWidth,
                            child: _EngineNode(),
                          ),
                          const SizedBox(width: _wireWidth),
                          Expanded(
                            child: Column(
                              children: [
                                for (final route in routes)
                                  SizedBox(
                                    height: _rowHeight,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 5,
                                      ),
                                      child: route,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          NetworkDashboardControls(
            platform: widget.platform ?? SupportPlatform.currentPlatform,
          ),
          const SizedBox(height: 28),
          const Divider(),
          const SizedBox(height: 18),
          _PathStats(targets: targets, services: services, exitOf: exitOf),
        ],
      ),
    );
  }
}

Color _routeColor(BuildContext context, int index) {
  const light = [
    Color(0xFF6F9C00),
    Color(0xFF2A78D6),
    Color(0xFF0F9FB0),
    Color(0xFFE0632F),
    Color(0xFF8B5CF6),
    Color(0xFFD55181),
  ];
  final color = light[index % light.length];
  return context.colorScheme.brightness == Brightness.dark
      ? Color.lerp(color, Colors.white, 0.2)!
      : color;
}

class _EntryNode extends ConsumerWidget {
  const _EntryNode();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hide = ref.watch(appSettingProvider.select((state) => state.hideIp));
    final localIp = ref.watch(localIpProvider);
    final labels = context.appLocalizations;
    return NetworkPanel(
      child: Row(
        spacing: 12,
        children: [
          const GlyphIcon(AppGlyphs.devices, size: 26),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 5,
              children: [
                Text(
                  labels.networkEntry,
                  style: AppTextStyle.subheadline.of(context, emphasized: true),
                ),
                Text(
                  hide ? '*****' : localIp ?? '—',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyle.caption1
                      .of(context)
                      .toJetBrainsMono
                      .copyWith(color: context.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EngineNode extends ConsumerWidget {
  const _EngineNode({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final running = ref.watch(isStartProvider);
    final hasProfile = ref.watch(
      profilesProvider.select((profiles) => profiles.isNotEmpty),
    );
    final mode = ref.watch(
      patchClashConfigProvider.select((config) => config.mode),
    );
    final scheme = context.colorScheme;
    final labels = context.appLocalizations;
    final action = FilledButton(
      onPressed: hasProfile
          ? () => ref.read(commonActionProvider.notifier).toggleRunning()
          : null,
      child: Text(running ? labels.stop : labels.start),
    );
    return NetworkPanel(
      accent: running ? scheme.success : null,
      child: compact
          ? Row(
              spacing: 12,
              children: [
                const GlyphIcon(AppGlyphs.split, size: 28),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 4,
                    children: [
                      Text(
                        labels.routingEngine,
                        style: AppTextStyle.caption1
                            .of(context)
                            .copyWith(color: scheme.onSurfaceVariant),
                      ),
                      Text(
                        appName,
                        style: AppTextStyle.title3.of(
                          context,
                          emphasized: true,
                        ),
                      ),
                      Text(
                        mode.label,
                        style: AppTextStyle.caption1
                            .of(context)
                            .copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                action,
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 10,
              children: [
                Text(
                  labels.routingEngine,
                  style: AppTextStyle.caption1
                      .of(context)
                      .copyWith(color: scheme.onSurfaceVariant),
                ),
                const GlyphIcon(AppGlyphs.split, size: 28),
                Text(
                  appName,
                  style: AppTextStyle.title3.of(context, emphasized: true),
                ),
                Text(
                  mode.label,
                  style: AppTextStyle.caption1
                      .of(context)
                      .copyWith(color: scheme.onSurfaceVariant),
                ),
                action,
              ],
            ),
    );
  }
}

class _LiveTraffic extends ConsumerWidget {
  const _LiveTraffic();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final traffic = ref.watch(
      trafficsProvider.select((state) => state.list.safeLast(const Traffic())),
    );
    final labels = context.appLocalizations;
    return Row(
      spacing: 18,
      children: [
        for (final (value, label, glyph, color) in [
          (
            traffic.down,
            labels.download,
            AppGlyphs.arrowDown,
            _routeColor(context, 0),
          ),
          (
            traffic.up,
            labels.upload,
            AppGlyphs.arrowUp,
            _routeColor(context, 4),
          ),
        ])
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 4,
              children: [
                Row(
                  spacing: 4,
                  children: [
                    GlyphIcon(glyph, size: 14, color: color),
                    Flexible(
                      child: Text(
                        '${value.traffic.value} ${value.traffic.unit}/s',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyle.subheadline
                            .of(context, emphasized: true)
                            .toTabular
                            .copyWith(color: color),
                      ),
                    ),
                  ],
                ),
                Text(
                  label,
                  style: AppTextStyle.caption2
                      .of(context)
                      .copyWith(color: context.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ServiceRoute extends ConsumerWidget {
  const _ServiceRoute({
    required this.target,
    required this.entry,
    required this.ip,
    required this.color,
    required this.onTap,
  });

  final ServiceTarget target;
  final ProbeEntry<ServiceCheck> entry;
  final IpInfo? ip;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hide = ref.watch(appSettingProvider.select((state) => state.hideIp));
    final labels = context.appLocalizations;
    final scheme = context.colorScheme;
    final check = entry.value;
    final pending = check == null && entry.phase != ProbePhase.failed;
    final status = check?.status;
    final statusColor = status == ServiceProbeStatus.available
        ? scheme.success
        : pending
        ? scheme.onSurfaceVariant
        : scheme.warning;
    final statusText = pending
        ? labels.servicePending
        : switch (status) {
            ServiceProbeStatus.available =>
              check?.delay == null
                  ? labels.serviceAvailable
                  : '${check!.delay} ms',
            ServiceProbeStatus.restricted => labels.serviceRestricted,
            ServiceProbeStatus.unavailable => labels.serviceUnavailable,
            ServiceProbeStatus.disallowedIsp => labels.serviceDisallowedIsp,
            ServiceProbeStatus.blocked => labels.serviceBlocked,
            ServiceProbeStatus.unsupportedRegion =>
              labels.serviceUnsupportedRegion,
            ServiceProbeStatus.timeout => labels.timeout,
            ServiceProbeStatus.originalsOnly => labels.serviceOriginalsOnly,
            ServiceProbeStatus.comingSoon => labels.serviceComingSoon,
            _ => labels.serviceFailed,
          };
    final flag = ip?.countryCode ?? check?.region;
    return Semantics(
      label: '${target.label}, $statusText',
      button: true,
      child: PressSurface(
        fill: SurfaceLevel.card.colorOf(scheme),
        shape: AppShape.sm,
        side: BorderSide(color: scheme.outlineVariant),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        onPressed: onTap,
        child: Row(
          spacing: 10,
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: ShapeDecoration(
                color: color.withValues(alpha: 0.1),
                shape: AppShape.sm,
              ),
              child: SvgPicture.asset(
                'assets/images/services/${target.icon}.svg',
                width: 20,
                height: 20,
                theme: SvgTheme(currentColor: scheme.onSurface),
                excludeFromSemantics: true,
              ),
            ),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 5,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          target.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyle.subheadline.of(
                            context,
                            emphasized: true,
                          ),
                        ),
                      ),
                      Flexible(
                        child: Text(
                          statusText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyle.caption2
                              .of(context)
                              .toTabular
                              .copyWith(color: statusColor),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    spacing: 5,
                    children: [
                      if (flag != null)
                        Text(
                          flag.countryFlagEmoji,
                          style: AppTextStyle.caption1
                              .of(context)
                              .copyWith(fontFamily: FontFamily.twEmoji.value),
                        ),
                      Expanded(
                        child: Text(
                          hide && ip != null
                              ? '*****'
                              : ip?.ip ?? check?.node ?? '—',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyle.caption1
                              .of(context)
                              .toJetBrainsMono
                              .copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ),
                      if (ip != null)
                        Text(
                          ip!.ip.contains(':') ? 'IPv6' : 'IPv4',
                          style: AppTextStyle.caption2
                              .of(context)
                              .copyWith(color: color),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PathStats extends StatelessWidget {
  const _PathStats({
    required this.targets,
    required this.services,
    required this.exitOf,
  });

  final List<ServiceTarget> targets;
  final RoutedProbeState<ServiceTarget, ServiceCheck> services;
  final IpInfo? Function(ServiceTarget) exitOf;

  @override
  Widget build(BuildContext context) {
    final labels = context.appLocalizations;
    final checks = [for (final target in targets) ?services.valueOf(target)];
    final addresses = {for (final target in targets) ?exitOf(target)?.ip};
    final dates = [for (final check in checks) ?check.checkedAt]..sort();
    final responding = checks
        .where(
          (check) =>
              check.status != ServiceProbeStatus.failed &&
              check.status != ServiceProbeStatus.timeout,
        )
        .length;
    final stats = [
      (labels.respondingSites, '$responding / ${targets.length}'),
      (labels.uniqueExits, '${addresses.length}'),
      ('IPv6', '${addresses.where((ip) => ip.contains(':')).length}'),
      (labels.lastChecked, dates.isEmpty ? '—' : _checkedTime(dates.last)),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 600 ? 4 : 2;
        return Wrap(
          runSpacing: 20,
          children: [
            for (final (label, value) in stats)
              SizedBox(
                width: constraints.maxWidth / columns,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 6,
                  children: [
                    Text(
                      label,
                      style: AppTextStyle.caption1
                          .of(context)
                          .copyWith(
                            color: context.colorScheme.onSurfaceVariant,
                          ),
                    ),
                    Text(
                      value,
                      style: AppTextStyle.title2
                          .of(context, emphasized: true)
                          .toTabular,
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

String _checkedTime(DateTime time) {
  final local = time.toLocal();
  return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}
