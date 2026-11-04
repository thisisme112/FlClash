import 'dart:math' as math;

import 'package:fl_clash/ui/ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

double _contrast(Color a, Color b) {
  final first = a.computeLuminance();
  final second = b.computeLuminance();
  return (math.max(first, second) + 0.05) / (math.min(first, second) + 0.05);
}

void main() {
  for (final brightness in Brightness.values) {
    test(
      '${brightness.name} surfaces remain distinct and text stays readable',
      () {
        final original = seededColorScheme(
          seedColor: const Color(0xFF3563E9),
          brightness: brightness,
          style: ColorStyle.vivid,
        );
        final scheme = vantageColorScheme(original);
        final levels = [
          for (final level in SurfaceLevel.values) level.colorOf(scheme),
        ];
        for (final surface in levels) {
          expect(_contrast(scheme.onSurface, surface), greaterThanOrEqualTo(7));
          expect(
            _contrast(scheme.onSurfaceVariant, surface),
            greaterThanOrEqualTo(4.5),
          );
        }
        for (var index = 1; index < levels.length; index++) {
          expect(levels[index], isNot(levels[index - 1]));
        }
        expect(scheme.primary, original.primary);
        expect(scheme.onPrimary, original.onPrimary);
      },
    );
  }

  test('pure black and user-selected accents remain available', () {
    final original = seededColorScheme(
      seedColor: const Color(0xFFD55181),
      brightness: Brightness.dark,
      style: ColorStyle.vivid,
    ).toPureBlack(true);
    final scheme = vantageColorScheme(original);
    expect(scheme.surface, Colors.black);
    expect(scheme.primary, original.primary);
  });
}
