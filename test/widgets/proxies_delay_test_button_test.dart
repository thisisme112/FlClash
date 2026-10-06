import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/proxies/delay_test_button.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/test_app.dart';
import '../helpers/test_profiles.dart';

class _RecordingProxiesAction extends ProxiesAction {
  static final List<String> tested = [];

  @override
  Future<void> delayTestPageGroup(String groupName) async {
    tested.add(groupName);
  }
}

Group _group(String name) => Group(
  type: GroupType.Selector,
  name: name,
  all: [Proxy(name: '$name-0', type: 'ss')],
);

void main() {
  late ProviderContainer container;

  Future<void> pumpButton(
    WidgetTester tester, {
    required Set<String> unfoldSet,
  }) async {
    final groups = [_group('G0'), _group('G1'), _group('G2')];
    final profile = Profile.normal().copyWith(unfoldSet: unfoldSet);
    _RecordingProxiesAction.tested.clear();
    container = ProviderContainer(
      overrides: [
        currentProfileIdProvider.overrideWithBuild((_, _) => profile.id),
        profilesProvider.overrideWith(() => TestProfiles([profile])),
        currentGroupsStateProvider.overrideWithValue(
          GroupsState(value: groups),
        ),
        proxiesActionProvider.overrideWith(_RecordingProxiesAction.new),
        proxiesStyleSettingProvider.overrideWithBuild(
          (_, _) => const ProxiesStyleProps(type: ProxiesType.list),
        ),
      ],
    );
    addTearDown(container.dispose);
    globalState.container = container;
    container.read(groupsProvider.notifier).value = groups;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: TestApp(
          homeBuilder: (child) => Scaffold(body: Center(child: child)),
          child: const ProxiesDelayTestButton(),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('the list layout tests every unfolded group', (tester) async {
    await pumpButton(tester, unfoldSet: {'G0', 'G2'});

    await tester.tap(find.byType(ProxiesDelayTestButton));
    await tester.pump();

    expect(_RecordingProxiesAction.tested, ['G0', 'G2']);
  });

  testWidgets('nothing unfolded leaves the button disabled', (tester) async {
    await pumpButton(tester, unfoldSet: {});

    expect(
      tester
          .widget<FloatingActionButton>(find.byType(FloatingActionButton))
          .onPressed,
      isNull,
    );
  });

  testWidgets('a group under test marches its dots and ignores taps', (
    tester,
  ) async {
    await pumpButton(tester, unfoldSet: {'G0'});

    container.read(delayTestingGroupsProvider.notifier).start('G0');
    await tester.pump();

    expect(find.byType(DotMarch), findsOneWidget);
    await tester.tap(find.byType(ProxiesDelayTestButton), warnIfMissed: false);
    await tester.pump();
    expect(_RecordingProxiesAction.tested, isEmpty);

    container.read(delayTestingGroupsProvider.notifier).stop('G0');
    await tester.pump();

    expect(find.byType(DotMarch), findsNothing);
  });
}
