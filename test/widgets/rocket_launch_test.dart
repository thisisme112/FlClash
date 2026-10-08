import 'package:fl_clash/widgets/rocket_launch.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

Widget _host({
  required bool launched,
  VoidCallback? onLaunch,
  VoidCallback? onContentTap,
  bool disableAnimations = false,
}) {
  return MaterialApp(
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(disableAnimations: disableAnimations),
        child: RocketLaunch(
          launched: launched,
          onLaunch: onLaunch ?? () {},
          restInset: const Offset(52, 52),
          padRadius: 31,
          label: 'Start',
          peekLabel: 'Peek',
          child: Center(
            child: TextButton(
              onPressed: onContentTap ?? () {},
              child: const Text('content'),
            ),
          ),
        ),
      ),
    ),
  );
}

Finder get _pad => find.byWidgetPredicate(
  (widget) => widget is Semantics && widget.properties.label == 'Start',
);

Finder get _content => find.text('content');

void main() {
  testWidgets('leaves only the pad until launched, and tapping it launches', (
    tester,
  ) async {
    var launches = 0;
    await tester.pumpWidget(_host(launched: false, onLaunch: () => launches++));

    expect(_content, findsNothing);
    expect(_pad, findsOneWidget);

    await tester.tap(_pad);
    expect(launches, 1);
  });

  testWidgets('parts the cover on launch and hands the child its taps', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(_host(launched: false));
    await tester.pumpWidget(_host(launched: true, onContentTap: () => taps++));
    await tester.pump(const Duration(milliseconds: 100));
    expect(_pad, findsNothing);
    expect(tester.hasRunningAnimations, isTrue);

    await tester.pumpAndSettle();
    await tester.tap(_content);
    expect(taps, 1);
  });

  testWidgets('lands back on the pad when stopped', (tester) async {
    await tester.pumpWidget(_host(launched: true));
    expect(_content, findsOneWidget);
    expect(_pad, findsNothing);

    await tester.pumpWidget(_host(launched: false));
    await tester.pumpAndSettle();
    expect(_content, findsNothing);
    expect(_pad, findsOneWidget);
  });

  testWidgets('a long press opens the cover without launching', (tester) async {
    var launches = 0;
    await tester.pumpWidget(_host(launched: false, onLaunch: () => launches++));

    await tester.longPress(_pad);
    await tester.pumpAndSettle();
    expect(launches, 0);
    expect(_content, findsOneWidget);

    await tester.pumpWidget(_host(launched: true));
    await tester.pumpWidget(_host(launched: false));
    await tester.pumpAndSettle();
    expect(_pad, findsOneWidget);
  });

  testWidgets('switches at once when animations are disabled', (tester) async {
    await tester.pumpWidget(_host(launched: false, disableAnimations: true));
    await tester.pumpWidget(_host(launched: true, disableAnimations: true));
    await tester.pump();

    expect(_content, findsOneWidget);
    expect(tester.hasRunningAnimations, isFalse);
  });
}
