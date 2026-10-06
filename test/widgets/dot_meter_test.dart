import 'package:fl_clash/widgets/dot_meter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

const _low = Color(0xFF00FF00);
const _high = Color(0xFFFF0000);
const _unlit = Color(0xFF222222);

final _canvas = find.descendant(
  of: find.byType(DotMeter),
  matching: find.byType(CustomPaint),
);

Widget _meter(List<double> values, {int capacity = 2}) {
  return Center(
    child: SizedBox(
      width: 40,
      height: 40,
      child: DotMeter(
        values: values,
        capacity: capacity,
        minScale: 1,
        colors: const [_low, _high],
        unlitColor: _unlit,
      ),
    ),
  );
}

void main() {
  testWidgets('a new sample redraws the meter and leaves nothing animating', (
    tester,
  ) async {
    await tester.pumpWidget(_meter(const [0, 10]));
    await tester.pumpWidget(_meter(const [0, 10, 5]));

    expect(
      tester.hasRunningAnimations,
      isFalse,
      reason: 'an animation here repaints the whole window on every vsync',
    );
    expect(
      tester.renderObject(_canvas),
      paints
        ..circle(color: _low)
        ..circle(color: _high)
        ..circle(color: _low)
        ..circle(color: _unlit),
    );
  });

  testWidgets('columns without a sample stay unlit and the newest is last', (
    tester,
  ) async {
    await tester.pumpWidget(_meter(const [10], capacity: 2));

    expect(
      tester.renderObject(_canvas),
      paints
        ..circle(color: _unlit, x: 10)
        ..circle(color: _unlit, x: 10)
        ..circle(color: _low, x: 30)
        ..circle(color: _high, x: 30),
    );
  });

  testWidgets('idle noise below the least scale lights one row at most', (
    tester,
  ) async {
    await tester.pumpWidget(_meter(const [0, 0.2]));

    expect(
      tester.renderObject(_canvas),
      paints
        ..circle(color: _unlit)
        ..circle(color: _unlit)
        ..circle(color: _low)
        ..circle(color: _unlit),
    );
  });
}
