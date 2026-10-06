import 'package:fl_clash/widgets/dot_signal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

const _lit = Color(0xFF00FF00);
const _unlit = Color(0xFF222222);

Widget _host(Widget child, {bool disableAnimations = false}) {
  return MediaQuery(
    data: MediaQueryData(disableAnimations: disableAnimations),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: Center(child: child),
    ),
  );
}

void main() {
  test('a delay lights fewer dots the slower it is and none on a timeout', () {
    expect(
      [
        -1,
        0,
        80,
        149,
        150,
        299,
        300,
        599,
        600,
        999,
        1000,
        5000,
      ].map(DotSignal.levelOfDelay),
      [0, 0, 5, 5, 4, 4, 3, 3, 2, 2, 1, 1],
    );
  });

  testWidgets('DotSignal lights its first dots only', (tester) async {
    await tester.pumpWidget(
      _host(
        const DotSignal(level: 2, color: _lit, unlitColor: _unlit, count: 3),
      ),
    );

    expect(
      tester.renderObject(find.byType(CustomPaint)),
      paints
        ..circle(color: _lit)
        ..circle(color: _lit)
        ..circle(color: _unlit),
    );
  });

  testWidgets('DotMarch moves its lit dot one step at a time', (tester) async {
    await tester.pumpWidget(
      _host(const DotMarch(color: _lit, unlitColor: _unlit)),
    );
    final canvas = find.byType(CustomPaint);

    expect(
      tester.renderObject(canvas),
      paints
        ..circle(color: _lit)
        ..circle(color: _unlit)
        ..circle(color: _unlit),
    );
    expect(tester.hasRunningAnimations, isFalse);

    await tester.pump(const Duration(milliseconds: 140));
    await tester.pump();

    expect(
      tester.renderObject(canvas),
      paints
        ..circle(color: _unlit)
        ..circle(color: _lit)
        ..circle(color: _unlit),
    );
  });

  testWidgets('DotMarch holds still when animations are disabled', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const DotMarch(color: _lit, unlitColor: _unlit),
        disableAnimations: true,
      ),
    );

    await tester.binding.delayed(const Duration(milliseconds: 500));

    expect(tester.binding.hasScheduledFrame, isFalse);
  });
}
