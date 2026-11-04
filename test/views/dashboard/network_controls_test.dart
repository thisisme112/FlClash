import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:fl_clash/views/dashboard/network_controls.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/host_scaffold.dart';
import '../../helpers/test_app.dart';
import '../../helpers/test_profiles.dart';

class _Proxies extends ProxiesAction {
  final changes = <(String, String)>[];

  @override
  void build() {}

  @override
  void changeProxyDebounce(String groupName, String proxyName) =>
      changes.add((groupName, proxyName));
}

class _Setup extends SetupAction {
  final modes = <Mode>[];

  @override
  void build() {}

  @override
  void changeMode(Mode mode) => modes.add(mode);
}

void main() {
  late _Proxies proxies;
  late _Setup setup;
  setUp(() {
    proxies = _Proxies();
    setup = _Setup();
  });

  Future<ProviderContainer> pump(
    WidgetTester tester, {
    SupportPlatform platform = SupportPlatform.Windows,
    bool connected = true,
    int members = 3,
    int groupCount = 1,
    bool quickOnly = false,
  }) async {
    final groups = [
      for (var i = 0; i < groupCount; i++)
        Group(
          name: 'Proxy $i',
          hidden: false,
          type: GroupType.Selector,
          all: [
            for (var n = 0; n < members; n++)
              Proxy(name: 'Node $n', type: 'ss'),
          ],
        ),
    ];
    await tester.pumpWidget(
      TestApp(
        overrides: [
          profilesProvider.overrideWith(TestProfiles.new),
          groupsProvider.overrideWithBuild((_, _) => groups),
          selectedMapProvider.overrideWith((_) => {'Proxy 0': 'Node 1'}),
          if (quickOnly)
            currentProfileProvider.overrideWith(
              (_) => const Profile(
                id: 1,
                autoUpdateDuration: Duration.zero,
                currentGroupName: 'Proxy 7',
              ),
            ),
          coreStatusProvider.overrideWithBuild(
            (_, _) =>
                connected ? CoreStatus.connected : CoreStatus.disconnected,
          ),
          proxiesActionProvider.overrideWith(() => proxies),
          setupActionProvider.overrideWith(() => setup),
        ],
        child: HostScaffold(
          body: TickerMode(
            enabled: false,
            child: SingleChildScrollView(
              child: quickOnly
                  ? const NetworkProxySwitch()
                  : NetworkDashboardControls(platform: platform),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    return ProviderScope.containerOf(tester.element(find.byType(HostScaffold)));
  }

  testWidgets('the top shortcut follows the current Proxies group', (
    tester,
  ) async {
    await pump(tester, quickOnly: true, groupCount: 12);
    expect(find.text('Proxy 7'), findsOneWidget);
    expect(find.text('Proxy 0'), findsNothing);
    await tester.tap(find.byTooltip('Next node'));
    expect(proxies.changes.single.$1, 'Proxy 7');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'next and previous delegate to the same Proxies action with real node names',
    (tester) async {
      await pump(tester);
      expect(find.text('Node 1'), findsOneWidget);
      await tester.ensureVisible(find.byTooltip('Next node'));
      await tester.tap(find.byTooltip('Next node'));
      await tester.tap(find.byTooltip('Previous node'));
      expect(proxies.changes, [('Proxy 0', 'Node 2'), ('Proxy 0', 'Node 0')]);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('the homepage shows at most four shortcuts with large profiles', (
    tester,
  ) async {
    await pump(tester, groupCount: 150, members: 300);
    expect(find.byTooltip('Next node'), findsNWidgets(4));
    expect(find.text('Proxy 4'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final connected in [false, true]) {
    testWidgets(
      'shortcut arrows are disabled with ${connected ? 'a single node' : 'a disconnected core'}',
      (tester) async {
        await pump(tester, connected: connected, members: connected ? 1 : 3);
        expect(
          tester
              .widget<IconButton>(
                find.byWidgetPredicate(
                  (widget) =>
                      widget is IconButton && widget.tooltip == 'Next node',
                ),
              )
              .onPressed,
          isNull,
        );
        expect(proxies.changes, isEmpty);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets('desktop takeover switches update the original settings', (
    tester,
  ) async {
    final container = await pump(tester);
    final switches = find.byType(Switch);
    expect(switches, findsNWidgets(2));
    final oldProxy = container.read(networkSettingProvider).systemProxy;
    await tester.ensureVisible(switches.first);
    await tester.tap(switches.first);
    await tester.pump();
    expect(container.read(networkSettingProvider).systemProxy, !oldProxy);
    await tester.tap(switches.last);
    await tester.pump();
    expect(container.read(patchClashConfigProvider).tun.enable, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Android offers the original VPN setting', (tester) async {
    final container = await pump(tester, platform: SupportPlatform.Android);
    expect(find.text('VPN'), findsOneWidget);
    expect(find.text('TUN'), findsNothing);
    final old = container.read(vpnSettingProvider).enable;
    await tester.ensureVisible(find.byType(Switch));
    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(container.read(vpnSettingProvider).enable, !old);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('mode changes delegate to the existing setup owner', (
    tester,
  ) async {
    await pump(tester);
    await tester.ensureVisible(find.text('Global'));
    await tester.tap(find.text('Global'));
    expect(setup.modes, [Mode.global]);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
