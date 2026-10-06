import 'dart:async';

import 'package:material_ui/material_ui.dart';

const _dotSize = 4.0;
const _dotGap = 3.0;

Size _rowSize(int count) =>
    Size(count * _dotSize + (count - 1) * _dotGap, _dotSize);

void _paintRow(Canvas canvas, int count, Color Function(int index) colorOf) {
  final paint = Paint();
  for (var index = 0; index < count; index++) {
    paint.color = colorOf(index);
    canvas.drawCircle(
      Offset(index * (_dotSize + _dotGap) + _dotSize / 2, _dotSize / 2),
      _dotSize / 2,
      paint,
    );
  }
}

/// A row of dots of which the first [level] are lit, as a signal strength.
class DotSignal extends StatelessWidget {
  const DotSignal({
    super.key,
    required this.level,
    required this.color,
    required this.unlitColor,
    this.count = 5,
  });

  /// Maps a delay in milliseconds to the dots a five dot signal lights.
  static int levelOfDelay(int delay) => switch (delay) {
    <= 0 => 0,
    < 150 => 5,
    < 300 => 4,
    < 600 => 3,
    < 1000 => 2,
    _ => 1,
  };

  final int level;
  final Color color;
  final Color unlitColor;
  final int count;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: _rowSize(count),
      painter: _DotSignalPainter(
        level: level,
        color: color,
        unlitColor: unlitColor,
        count: count,
      ),
    );
  }
}

class _DotSignalPainter extends CustomPainter {
  _DotSignalPainter({
    required this.level,
    required this.color,
    required this.unlitColor,
    required this.count,
  });

  final int level;
  final Color color;
  final Color unlitColor;
  final int count;

  @override
  void paint(Canvas canvas, Size size) {
    _paintRow(canvas, count, (index) => index < level ? color : unlitColor);
  }

  @override
  bool shouldRepaint(_DotSignalPainter oldDelegate) {
    return oldDelegate.level != level ||
        oldDelegate.color != color ||
        oldDelegate.unlitColor != unlitColor ||
        oldDelegate.count != count;
  }
}

/// A progress mark whose single lit dot steps along the row.
class DotMarch extends StatefulWidget {
  const DotMarch({
    super.key,
    required this.color,
    required this.unlitColor,
    this.count = 3,
  });

  final Color color;
  final Color unlitColor;
  final int count;

  @override
  State<DotMarch> createState() => _DotMarchState();
}

class _DotMarchState extends State<DotMarch> {
  // A ticker would repaint on every vsync; the mark only moves in steps.
  static const _step = Duration(milliseconds: 140);

  final _lit = ValueNotifier<int>(0);
  Timer? _timer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final canAnimate =
        !MediaQuery.disableAnimationsOf(context) &&
        TickerMode.valuesOf(context).enabled;
    if (!canAnimate) {
      _timer?.cancel();
      _timer = null;
      return;
    }
    _timer ??= Timer.periodic(_step, (_) {
      _lit.value = (_lit.value + 1) % widget.count;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _lit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        size: _rowSize(widget.count),
        painter: _DotMarchPainter(
          lit: _lit,
          color: widget.color,
          unlitColor: widget.unlitColor,
          count: widget.count,
        ),
      ),
    );
  }
}

class _DotMarchPainter extends CustomPainter {
  _DotMarchPainter({
    required this.lit,
    required this.color,
    required this.unlitColor,
    required this.count,
  }) : super(repaint: lit);

  final ValueNotifier<int> lit;
  final Color color;
  final Color unlitColor;
  final int count;

  @override
  void paint(Canvas canvas, Size size) {
    _paintRow(
      canvas,
      count,
      (index) => index == lit.value % count ? color : unlitColor,
    );
  }

  @override
  bool shouldRepaint(_DotMarchPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.unlitColor != unlitColor ||
        oldDelegate.count != count;
  }
}
