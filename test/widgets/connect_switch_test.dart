import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/dashboard/widgets/connect_switch.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/test_app.dart';

class _RecordingSetupAction extends SetupAction {
  final requests = <bool>[];

  @override
  Future<bool> setRunning(bool running, {bool initialize = false}) {
    requests.add(running);
    ref.read(runTimeProvider.notifier).value = running ? 1 : null;
    return Future.value(true);
  }
}

void main() {
  Future<ProviderContainer> pumpSwitch(
    WidgetTester tester, {
    int? runTime,
    bool suspend = false,
    double? width,
  }) async {
    final container = ProviderContainer(
      overrides: [
        initProvider.overrideWithBuild((_, _) => true),
        profilesProvider.overrideWithValue([
          const Profile(id: 1, autoUpdateDuration: Duration.zero),
        ]),
        suspendProvider.overrideWithValue(suspend),
        setupActionProvider.overrideWith(_RecordingSetupAction.new),
      ],
    );
    addTearDown(container.dispose);
    globalState.container = container;
    container.read(runTimeProvider.notifier).value = runTime;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: TestApp(
          includeNavigatorKey: false,
          homeBuilder: (child) => Scaffold(body: Center(child: child)),
          child: SizedBox(width: width, child: const ConnectSwitch()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('dispatches each toggle through the shared running state', (
    tester,
  ) async {
    final container = await pumpSwitch(tester, runTime: 1);
    final action =
        container.read(setupActionProvider.notifier) as _RecordingSetupAction;

    await tester.tap(find.byType(ConnectSwitch));
    expect(action.requests, [false]);
    expect(container.read(isStartProvider), isFalse);

    await tester.tap(find.byType(ConnectSwitch));
    expect(action.requests, [false, true]);
    expect(container.read(isStartProvider), isTrue);
  });

  testWidgets('shows the run time only while started', (tester) async {
    final container = await pumpSwitch(
      tester,
      runTime: const Duration(hours: 2, minutes: 13, seconds: 8).inMilliseconds,
    );

    expect(find.text('Connected'), findsOneWidget);
    expect(find.text('02:13:08'), findsOneWidget);

    container.read(runTimeProvider.notifier).value = null;
    await tester.pumpAndSettle();

    expect(find.text('Start'), findsOneWidget);
    expect(find.text('02:13:08'), findsNothing);
  });

  testWidgets('moves the knob to the end when started', (tester) async {
    final container = await pumpSwitch(tester);
    final knob = find.descendant(
      of: find.byType(AnimatedAlign),
      matching: find.byType(AnimatedContainer),
    );
    final stopped = tester.getCenter(knob).dx;

    container.read(runTimeProvider.notifier).value = 1;
    await tester.pumpAndSettle();

    expect(tester.getCenter(knob).dx, greaterThan(stopped));
  });

  testWidgets('keeps the label clear of the knob on a narrow switch', (
    tester,
  ) async {
    await pumpSwitch(tester, runTime: 1, width: 180);

    final knob = find.descendant(
      of: find.byType(AnimatedAlign),
      matching: find.byType(AnimatedContainer),
    );
    expect(tester.takeException(), isNull);
    expect(
      tester.getRect(find.text('Connected')).right,
      lessThanOrEqualTo(tester.getRect(knob).left),
    );
  });

  testWidgets('names the suspended state while the core is held', (
    tester,
  ) async {
    await pumpSwitch(tester, runTime: 1, suspend: true);

    final context = tester.element(find.byType(ConnectSwitch));
    expect(find.text(context.appLocalizations.suspended), findsOneWidget);
  });
}
