import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/dashboard/widgets/access_plate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/test_app.dart';
import '../helpers/test_profiles.dart';

void main() {
  Future<void> pumpPlate(
    WidgetTester tester, {
    bool disableAnimations = false,
  }) async {
    final profile = Profile.normal().copyWith(label: 'Home line');
    final container = ProviderContainer(
      overrides: [
        currentProfileIdProvider.overrideWithBuild((_, _) => profile.id),
        profilesProvider.overrideWith(() => TestProfiles([profile])),
      ],
    );
    addTearDown(container.dispose);
    globalState.container = container;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: TestApp(
          includeNavigatorKey: false,
          homeBuilder: (child) => Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(disableAnimations: disableAnimations),
              child: Scaffold(body: Center(child: child)),
            ),
          ),
          child: const AccessPlate(),
        ),
      ),
    );
  }

  double tileOpacity(WidgetTester tester) => tester
      .widget<FadeTransition>(
        find.descendant(
          of: find.byType(AccessPlate),
          matching: find.byType(FadeTransition),
        ),
      )
      .opacity
      .value;

  testWidgets('reveals once, then names the app and the profile in use', (
    tester,
  ) async {
    await pumpPlate(tester);

    expect(tileOpacity(tester), 0);

    await tester.pumpAndSettle();

    expect(tileOpacity(tester), 1);
    expect(find.text('FLCLASH'), findsNWidgets(2));
    expect(find.text('Home line'), findsOneWidget);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('stands revealed at once when animations are disabled', (
    tester,
  ) async {
    await pumpPlate(tester, disableAnimations: true);

    expect(tileOpacity(tester), 1);
    expect(tester.hasRunningAnimations, isFalse);
  });
}
