import 'package:fl_clash/widgets/ignition.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

Widget _host({required bool active, bool disableAnimations = false}) {
  return MaterialApp(
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(disableAnimations: disableAnimations),
        child: Ignition(
          active: active,
          origin: Alignment.bottomRight,
          child: const ColoredBox(color: Color(0xFFFF0000)),
        ),
      ),
    ),
  );
}

bool _isFiltered(WidgetTester tester) =>
    tester.layers.whereType<ColorFilterLayer>().isNotEmpty;

Finder get _burst => find.descendant(
  of: find.byType(Ignition),
  matching: find.byWidgetPredicate(
    (widget) => widget is CustomPaint && widget.painter != null,
  ),
);

void main() {
  testWidgets('stays gray while idle and paints unfiltered once lit', (
    tester,
  ) async {
    await tester.pumpWidget(_host(active: false));
    expect(_isFiltered(tester), isTrue);

    await tester.pumpWidget(_host(active: true));
    await tester.pump(const Duration(milliseconds: 100));
    expect(_burst, findsOneWidget);

    await tester.pumpAndSettle();
    expect(_isFiltered(tester), isFalse);
    expect(_burst, findsNothing);
  });

  testWidgets('fades back to gray without a burst when stopped', (
    tester,
  ) async {
    await tester.pumpWidget(_host(active: true));
    expect(_isFiltered(tester), isFalse);

    await tester.pumpWidget(_host(active: false));
    await tester.pump(const Duration(milliseconds: 100));
    expect(_burst, findsNothing);

    await tester.pumpAndSettle();
    expect(_isFiltered(tester), isTrue);
  });

  testWidgets('switches at once when animations are disabled', (tester) async {
    await tester.pumpWidget(_host(active: false, disableAnimations: true));
    await tester.pumpWidget(_host(active: true, disableAnimations: true));
    await tester.pump();

    expect(_isFiltered(tester), isFalse);
    expect(tester.hasRunningAnimations, isFalse);
  });
}
