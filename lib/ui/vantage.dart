import 'dart:ui' show PointMode;

import 'package:flutter/widgets.dart';
import 'package:prism_ui/prism_ui.dart';

ColorScheme vantageColorScheme(
  ColorScheme scheme, {
  ColorStyle style = ColorStyle.vivid,
}) {
  if (scheme.surface == Colors.black || style == ColorStyle.tinted) {
    return scheme;
  }
  final dark = scheme.brightness == Brightness.dark;
  return scheme.copyWith(
    surface: dark ? const Color(0xFF0F1113) : const Color(0xFFF8F9FB),
    surfaceDim: dark ? const Color(0xFF0F1113) : const Color(0xFFECEEF1),
    surfaceBright: dark ? const Color(0xFF262A2F) : const Color(0xFFFFFFFF),
    surfaceContainerLowest: dark
        ? const Color(0xFF0B0D0F)
        : const Color(0xFFFFFFFF),
    surfaceContainerLow: dark
        ? const Color(0xFF131619)
        : const Color(0xFFF6F7F9),
    surfaceContainer: dark ? const Color(0xFF171A1D) : const Color(0xFFF3F4F6),
    surfaceContainerHigh: dark
        ? const Color(0xFF1D2024)
        : const Color(0xFFECEEF1),
    surfaceContainerHighest: dark
        ? const Color(0xFF262A2F)
        : const Color(0xFFE5E8ED),
    onSurface: dark ? const Color(0xFFE8EAED) : const Color(0xFF15181C),
    onSurfaceVariant: dark ? const Color(0xFFB4BAC2) : const Color(0xFF4B525B),
    outline: dark ? const Color(0xFF8C939C) : const Color(0xFF5F666F),
    outlineVariant: dark ? const Color(0xFF3A4047) : const Color(0xFFCBD0D6),
  );
}

class VantageBackdrop extends StatelessWidget {
  const VantageBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: CustomPaint(
      painter: _DotsPainter(
        context.colorScheme.outlineVariant.withValues(alpha: 0.55),
      ),
      child: child,
    ),
  );
}

class _DotsPainter extends CustomPainter {
  const _DotsPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    const step = 20.0;
    final points = <Offset>[
      for (double x = step / 2; x < size.width; x += step)
        for (double y = step / 2; y < size.height; y += step) Offset(x, y),
    ];
    canvas.drawPoints(
      PointMode.points,
      points,
      Paint()
        ..color = color
        ..strokeWidth = 1.3
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_DotsPainter oldDelegate) => oldDelegate.color != color;
}
