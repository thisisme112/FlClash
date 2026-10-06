import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

/// A level meter of dots: one column per sample with the newest at the end,
/// each lit from the bottom up to its share of the tallest sample.
class DotMeter extends StatelessWidget {
  const DotMeter({
    super.key,
    required this.values,
    required this.capacity,
    required this.minScale,
    required this.colors,
    required this.unlitColor,
  }) : assert(capacity > 0),
       assert(minScale > 0);

  final List<double> values;

  final int capacity;

  /// The least value the top row stands for, so idle noise stays low.
  final double minScale;

  /// One color per row, bottom first.
  final List<Color> colors;

  final Color unlitColor;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: SizedBox.expand(
        child: CustomPaint(
          painter: _DotMeterPainter(
            values: values,
            capacity: capacity,
            minScale: minScale,
            colors: colors,
            unlitColor: unlitColor,
          ),
        ),
      ),
    );
  }
}

class _DotMeterPainter extends CustomPainter {
  _DotMeterPainter({
    required this.values,
    required this.capacity,
    required this.minScale,
    required this.colors,
    required this.unlitColor,
  });

  static const _maxRadius = 3.0;
  static const _fill = 0.3;

  final List<double> values;
  final int capacity;
  final double minScale;
  final List<Color> colors;
  final Color unlitColor;

  int _levelOf(double value, double scale) {
    if (value <= 0) {
      return 0;
    }
    return (value / scale * colors.length).ceil().clamp(1, colors.length);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final rows = colors.length;
    if (rows == 0 || size.isEmpty) {
      return;
    }
    final cellWidth = size.width / capacity;
    final cellHeight = size.height / rows;
    final radius = math.min(
      math.min(cellWidth, cellHeight) * _fill,
      _maxRadius,
    );
    final scale = values.fold(minScale, math.max);
    final shown = math.min(values.length, capacity);
    final first = values.length - shown;
    final empty = capacity - shown;
    final paint = Paint();
    for (var column = 0; column < capacity; column++) {
      final sample = column < empty ? 0.0 : values[first + column - empty];
      final level = _levelOf(sample, scale);
      final x = (column + 0.5) * cellWidth;
      for (var row = 0; row < rows; row++) {
        paint.color = row < level ? colors[row] : unlitColor;
        canvas.drawCircle(
          Offset(x, size.height - (row + 0.5) * cellHeight),
          radius,
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_DotMeterPainter oldDelegate) {
    return !listEquals(oldDelegate.values, values) ||
        oldDelegate.capacity != capacity ||
        oldDelegate.minScale != minScale ||
        !listEquals(oldDelegate.colors, colors) ||
        oldDelegate.unlitColor != unlitColor;
  }
}
