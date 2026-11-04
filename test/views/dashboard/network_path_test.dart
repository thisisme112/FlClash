import 'dart:io';
import 'dart:ui' as ui;

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/common/service_probe.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/features/ip_quality/ip_quality_summary.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/ip_quality.dart';
import 'package:fl_clash/providers/outbound_ip.dart';
import 'package:fl_clash/providers/claude_outbound_ip.dart';
import 'package:fl_clash/views/dashboard/route_flow.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/providers/routed_probe.dart';
import 'package:fl_clash/providers/service_status.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:fl_clash/views/dashboard/network_path.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' show ProviderScope;
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/host_scaffold.dart';
import '../../helpers/test_app.dart';

const _ip = '203.0.113.42';
const _claudeIp = '203.0.113.44';
const _quality = IpQuality(
  ip: _ip,
  source: IpQualitySource.netCoffee,
  type: IpType.hosting,
  trustScore: 74,
  asn: 64500,
  country: 'Japan',
  countryCode: 'JP',
  isProxy: true,
  reportedFlags: ['is_proxy', 'is_vpn', 'is_tor', 'is_crawler', 'is_abuser'],
);

class _Actions extends CommonAction {
  int toggles = 0;

  @override
  void toggleRunning() => toggles++;
}

class _Services extends ServiceStatus {
  _Services({this.empty = false});

  final bool empty;
  final watched = <ServiceTarget>{};
  int refreshes = 0;

  @override
  RoutedProbeState<ServiceTarget, ServiceCheck> build() => RoutedProbeState({
    if (!empty)
      for (final (index, target) in ServiceTarget.values.take(6).indexed)
        target: ProbeEntry(
          phase: ProbePhase.fresh,
          value: ServiceCheck(
            index == 4
                ? ServiceProbeStatus.restricted
                : ServiceProbeStatus.available,
            delay: 34 + index * 8,
            chains: ['Exit $index'],
            region: index.isEven ? 'JP' : 'US',
            checkedAt: DateTime(2026, 11, 4, 14, 8),
          ),
        ),
  });

  @override
  void watch(ServiceTarget target) => watched.add(target);

  @override
  void unwatch(ServiceTarget target) => watched.remove(target);

  @override
  void refresh(Iterable<ServiceTarget> targets) => refreshes++;
}

class _Ips extends OutboundIpProbe {
  _Ips({this.empty = false});

  final bool empty;
  final watched = <String>{};
  int refreshes = 0;

  @override
  RoutedProbeState<String, IpInfo> build() => RoutedProbeState({
    if (!empty) ...{
      routedOutbound: const ProbeEntry(
        phase: ProbePhase.fresh,
        value: IpInfo(ip: _ip, countryCode: 'JP'),
      ),
      for (var index = 0; index < 6; index++)
        'Exit $index': ProbeEntry(
          phase: ProbePhase.fresh,
          value: IpInfo(
            ip: index.isEven ? _ip : '2001:db8::$index',
            countryCode: index.isEven ? 'JP' : 'US',
          ),
        ),
    },
  });

  @override
  void watch(String target) => watched.add(target);

  @override
  void unwatch(String target) => watched.remove(target);

  @override
  void refresh(Iterable<String> targets) => refreshes++;
}

class _ClaudeIps extends ClaudeOutboundIpProbe {
  _ClaudeIps({this.ip = _claudeIp, this.phase = ProbePhase.fresh});
  final ProbePhase phase;
  final String? ip;
  final watched = <String>{};
  int refreshes = 0;

  @override
  RoutedProbeState<String, IpInfo> build() => RoutedProbeState({
    routedOutbound: ProbeEntry(
      phase: phase,
      value: ip == null ? null : IpInfo(ip: ip!, countryCode: 'US'),
    ),
  });

  @override
  void watch(String target) => watched.add(target);

  @override
  void unwatch(String target) => watched.remove(target);

  @override
  void refresh(Iterable<String> targets) => refreshes++;
}

void main() {
  setUpAll(() async {
    final fontPath = Platform.environment['FLCLASH_PREVIEW_FONT'];
    if (fontPath == null) return;
    final bytes = await File(fontPath).readAsBytes();
    for (final family in ['Roboto', 'Segoe UI']) {
      await (FontLoader(
        family,
      )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
    }
    await (FontLoader('JetBrainsMono')
          ..addFont(rootBundle.load('assets/fonts/JetBrainsMono-Regular.ttf')))
        .load();
    await (FontLoader(
      'Twemoji',
    )..addFont(rootBundle.load('assets/fonts/Twemoji.Mozilla.ttf'))).load();
  });
  late _Services services;
  late _Ips ips;
  late _Actions actions;
  late _ClaudeIps claudeIps;
  final requestedAddresses = <String>[];
  var qualityRequests = 0;
  const boundaryKey = ValueKey('network-preview');

  setUp(() {
    services = _Services();
    ips = _Ips();
    actions = _Actions();
    claudeIps = _ClaudeIps();
    requestedAddresses.clear();
    qualityRequests = 0;
  });

  Future<void> pump(
    WidgetTester tester, {
    Size size = const Size(1440, 900),
    Brightness brightness = Brightness.light,
    bool hideIp = false,
    bool failQuality = false,
    TargetPlatform platform = TargetPlatform.windows,
    bool hasProfile = true,
    bool running = true,
    bool reducedMotion = true,
    bool claudeEnabled = true,
    IpQuality? claudeQuality,
    IpQuality quality = _quality,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final scheme = vantageColorScheme(
      seededColorScheme(
        seedColor: const Color(defaultPrimaryColor),
        brightness: brightness,
        style: ColorStyle.vivid,
      ),
    );
    await tester.pumpWidget(
      TestApp(
        locale: const Locale('en'),
        themeMode: brightness == Brightness.light
            ? ThemeMode.light
            : ThemeMode.dark,
        theme: ThemeData(colorScheme: scheme, platform: platform),
        darkTheme: ThemeData(colorScheme: scheme, platform: platform),
        overrides: [
          viewSizeProvider.overrideWithBuild((_, _) => size),
          appSettingProvider.overrideWithBuild(
            (_, _) => AppSettingProps(hideIp: hideIp),
          ),
          serviceStatusProvider.overrideWith(() => services),
          if (!claudeEnabled)
            enabledServiceTargetsProvider.overrideWith(
              (_) => [ServiceTarget.google],
            ),
          outboundIpProbeProvider.overrideWith(() => ips),
          claudeOutboundIpProbeProvider.overrideWith(() => claudeIps),
          profilesProvider.overrideWithValue(
            hasProfile
                ? const [Profile(id: 1, autoUpdateDuration: Duration.zero)]
                : const [],
          ),
          runTimeProvider.overrideWithBuild((_, _) => running ? 1 : null),
          commonActionProvider.overrideWith(() => actions),
          ipQualityProvider.overrideWith((_, address) async {
            requestedAddresses.add(address);
            qualityRequests++;
            if (failQuality) throw StateError('unavailable');
            return address == _claudeIp
                ? claudeQuality ??
                      quality.copyWith(
                        ip: _claudeIp,
                        trustScore: 86,
                        country: 'United States',
                        countryCode: 'US',
                      )
                : quality;
          }),
        ],
        homeBuilder: (child) => MediaQuery(
          data: MediaQueryData(
            size: size,
            disableAnimations: reducedMotion,
            textScaler: TextScaler.linear(
              tester.platformDispatcher.textScaleFactor,
            ),
          ),
          child: child,
        ),
        child: RepaintBoundary(
          key: boundaryKey,
          child: HostScaffold(
            body: VantageBackdrop(
              child: NetworkPathView(
                platform: platform == TargetPlatform.android
                    ? SupportPlatform.Android
                    : SupportPlatform.Windows,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  for (final platform in [TargetPlatform.windows, TargetPlatform.android]) {
    for (final brightness in Brightness.values) {
      testWidgets(
        '${platform.name} ${brightness.name} renders real source scores and responsive routes',
        (tester) async {
          final motionOutput = Platform.environment['FLCLASH_UI_MOTION_DIR'];
          final captureMotion =
              motionOutput != null &&
              platform == TargetPlatform.windows &&
              brightness == Brightness.dark;
          await pump(
            tester,
            reducedMotion: !captureMotion,
            size: platform == TargetPlatform.windows
                ? const Size(1440, 900)
                : const Size(390, 844),
            brightness: brightness,
            platform: platform,
          );
          expect(find.text('74'), findsOneWidget);
          expect(find.text('86'), findsOneWidget);
          expect(find.text('Claude trust score'), findsOneWidget);
          expect(find.text('Net.Coffee'), findsNWidgets(2));
          expect(find.text('AS64500 · Japan'), findsOneWidget);
          expect(find.text('FlClash'), findsNWidgets(2));
          expect(tester.takeException(), isNull);
          final output = Platform.environment['FLCLASH_UI_PREVIEW_DIR'];
          if (output != null) {
            final boundary = tester.renderObject<RenderRepaintBoundary>(
              find.byKey(boundaryKey),
            );
            await tester.runAsync(() async {
              final image = await boundary.toImage();
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              await Directory(output).create(recursive: true);
              await File(
                '$output/${platform.name}-${brightness.name}.png',
              ).writeAsBytes(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }
          if (captureMotion) {
            final boundary = tester.renderObject<RenderRepaintBoundary>(
              find.byKey(boundaryKey),
            );
            for (var frame = 0; frame < 60; frame++) {
              await tester.pump(const Duration(microseconds: 66667));
              await tester.runAsync(() async {
                final image = await boundary.toImage();
                final bytes = await image.toByteData(
                  format: ui.ImageByteFormat.png,
                );
                await Directory(motionOutput).create(recursive: true);
                await File(
                  '$motionOutput/${frame.toString().padLeft(3, '0')}.png',
                ).writeAsBytes(bytes!.buffer.asUint8List());
                image.dispose();
              });
            }
          }
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }

  testWidgets(
    'refresh uses existing probes and disposal releases every subscription',
    (tester) async {
      await pump(tester);
      expect(services.watched.length, 6);
      expect(ips.watched.length, 7);
      expect(
        ProviderScope.containerOf(
          tester.element(find.byType(NetworkPathView)),
        ).read(shownServiceCountProvider),
        6,
      );
      await tester.tap(find.byTooltip('Check again'));
      expect(services.refreshes, 1);
      expect(ips.refreshes, 1);
      await tester.pump();
      expect(qualityRequests, 4);
      expect(claudeIps.refreshes, 1);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(services.watched, isEmpty);
      expect(ips.watched, isEmpty);
      expect(claudeIps.watched, isEmpty);
    },
  );

  testWidgets('the engine button uses the existing lifecycle action', (
    tester,
  ) async {
    await pump(tester, running: false);
    await tester.tap(find.text('Start'));
    expect(actions.toggles, 1);
  });

  testWidgets('the engine cannot start without a profile', (tester) async {
    await pump(tester, hasProfile: false, running: false);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    expect(actions.toggles, 0);
  });

  testWidgets('unreported risk flags stay unknown rather than safe', (
    tester,
  ) async {
    await pump(
      tester,
      quality: _quality.copyWith(reportedFlags: [], isProxy: false),
    );
    expect(find.text('VPN · Unknown'), findsNWidgets(2));
    expect(find.textContaining('Not detected'), findsNothing);
  });

  testWidgets('a small Android viewport remains usable at large text scale', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.4;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pump(
      tester,
      size: const Size(320, 720),
      platform: TargetPlatform.android,
    );
    expect(tester.takeException(), isNull);
    await tester.drag(
      find.byType(SingleChildScrollView).first,
      const Offset(0, -900),
    );
    await tester.pumpAndSettle();
    expect(find.text('Last checked'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'hidden addresses do not leak from either quality or service rows',
    (tester) async {
      await pump(tester, hideIp: true);
      expect(find.text(_ip), findsNothing);
      expect(find.text(_claudeIp), findsNothing);
      expect(find.textContaining('2001:db8:'), findsNothing);
      expect(find.text('*****'), findsWidgets);
    },
  );

  testWidgets(
    'missing exits show pending instead of a made-up address or score',
    (tester) async {
      services = _Services(empty: true);
      ips = _Ips(empty: true);
      claudeIps = _ClaudeIps(ip: null);
      await pump(tester);
      expect(find.text('74'), findsNothing);
      expect(find.text(_ip), findsNothing);
      expect(find.text('Net.Coffee'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Claude looks up its actual exit instead of the general exit', (
    tester,
  ) async {
    await pump(tester);
    expect(requestedAddresses.toSet(), {_ip, _claudeIp});
    expect(find.text(_claudeIp), findsNWidgets(2));
    expect(find.text('86'), findsOneWidget);
  });

  testWidgets('a failed Claude trace shows an explicit error without a score', (
    tester,
  ) async {
    claudeIps = _ClaudeIps(ip: null, phase: ProbePhase.failed);
    await pump(tester);
    expect(requestedAddresses, [_ip]);
    expect(find.text('Could not detect the Claude exit IP'), findsOneWidget);
    expect(find.text('86'), findsNothing);
    expect(
      find.descendant(
        of: find.byWidgetPredicate(
          (widget) => widget is IpQualitySummary && widget.claude,
        ),
        matching: find.text('0'),
      ),
      findsNothing,
    );
    await tester.tap(find.byTooltip('Check again'));
    expect(claudeIps.refreshes, 1);
  });

  testWidgets('a shared exit reuses the same backend score request', (
    tester,
  ) async {
    claudeIps = _ClaudeIps(ip: _ip);
    await pump(tester);
    expect(qualityRequests, 1);
    expect(find.text('74'), findsNWidgets(2));
    await tester.tap(find.byTooltip('Check again'));
    await tester.pump();
    expect(qualityRequests, 2);
  });

  testWidgets('missing Claude exit never borrows the general exit score', (
    tester,
  ) async {
    claudeIps = _ClaudeIps(ip: null);
    await pump(tester);
    expect(requestedAddresses, [_ip]);
    expect(find.text('86'), findsNothing);
    expect(find.text('74'), findsOneWidget);
  });

  testWidgets('Claude region policy preserves the general IP score', (
    tester,
  ) async {
    await pump(
      tester,
      claudeQuality: _quality.copyWith(
        ip: _claudeIp,
        trustScore: 96,
        countryCode: 'HK',
        country: 'Hong Kong',
      ),
    );
    expect(find.text('74'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byWidgetPredicate(
          (widget) => widget is IpQualitySummary && widget.claude,
        ),
        matching: find.text('0'),
      ),
      findsOneWidget,
    );
    expect(find.text('Region restricted'), findsOneWidget);
    expect(find.textContaining('Net.Coffee assigns 0'), findsOneWidget);
  });

  testWidgets('disabled Claude has no subscription or assessment request', (
    tester,
  ) async {
    await pump(tester, claudeEnabled: false);
    expect(claudeIps.watched, isEmpty);
    expect(requestedAddresses, [_ip]);
    expect(find.text('Claude trust score'), findsNothing);
  });

  testWidgets('background and stopped core disable route motion', (
    tester,
  ) async {
    await pump(tester, reducedMotion: false);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(NetworkPathView)),
    );
    container.read(appVisibleProvider.notifier).value = false;
    await tester.pump();
    expect(
      tester.widget<NetworkRouteFlow>(find.byType(NetworkRouteFlow)).animate,
      isFalse,
    );
    container.read(appVisibleProvider.notifier).value = true;
    await tester.pump();
    expect(
      tester.widget<NetworkRouteFlow>(find.byType(NetworkRouteFlow)).animate,
      isTrue,
    );
    container.read(runTimeProvider.notifier).value = null;
    await tester.pump();
    expect(
      tester.widget<NetworkRouteFlow>(find.byType(NetworkRouteFlow)).animate,
      isFalse,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('pause and resume control the path animation', (tester) async {
    await pump(tester, reducedMotion: false);
    expect(
      tester.widget<NetworkRouteFlow>(find.byType(NetworkRouteFlow)).animate,
      isTrue,
    );
    await tester.tap(find.byTooltip('Pause path animation'));
    await tester.pump();
    expect(
      tester.widget<NetworkRouteFlow>(find.byType(NetworkRouteFlow)).animate,
      isFalse,
    );
    await tester.tap(find.byTooltip('Resume path animation'));
    await tester.pump();
    expect(
      tester.widget<NetworkRouteFlow>(find.byType(NetworkRouteFlow)).animate,
      isTrue,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'a failed score lookup leaves routes visible and the refresh enabled',
    (tester) async {
      await pump(tester, failQuality: true);
      expect(find.text('74'), findsNothing);
      expect(find.text('Google'), findsOneWidget);
      await tester.tap(find.byTooltip('Check again'));
      expect(services.refreshes, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
