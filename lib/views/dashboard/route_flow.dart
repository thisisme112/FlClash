import 'dart:ui' show PathMetric;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

class NetworkRouteFlow extends StatefulWidget {
  const NetworkRouteFlow({
    super.key,
    required this.routes,
    required this.animate,
    this.vertical = false,
    this.engineWidth = 156,
    this.wireWidth = 40,
    required this.child,
  });

  final List<(Color, bool)> routes;
  final bool animate;
  final bool vertical;
  final double engineWidth;
  final double wireWidth;
  final Widget child;

  @override
  State<NetworkRouteFlow> createState() => _NetworkRouteFlowState();
}

class _NetworkRouteFlowState extends State<NetworkRouteFlow>
    with SingleTickerProviderStateMixin {
  late final _phase = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(NetworkRouteFlow oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    final moving =
        widget.animate &&
        widget.routes.any((route) => route.$2) &&
        TickerMode.valuesOf(context).enabled &&
        !MediaQuery.disableAnimationsOf(context);
    if (moving && !_phase.isAnimating) {
      _phase.repeat();
    } else if (!moving && _phase.isAnimating) {
      _phase.stop();
    }
  }

  @override
  void dispose() {
    _phase.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: CustomPaint(
      painter: _RouteFlowPainter(
        phase: _phase,
        routes: widget.routes,
        vertical: widget.vertical,
        engineWidth: widget.engineWidth,
        wireWidth: widget.wireWidth,
      ),
      child: RepaintBoundary(child: widget.child),
    ),
  );
}

class _RouteFlowPainter extends CustomPainter {
  _RouteFlowPainter({
    required this.phase,
    required this.routes,
    required this.vertical,
    required this.engineWidth,
    required this.wireWidth,
  }) : super(repaint: phase);

  final Animation<double> phase;
  final List<(Color, bool)> routes;
  final bool vertical;
  final double engineWidth;
  final double wireWidth;
  Size? _size;
  final _paths = <Path>[];
  final _metrics = <PathMetric>[];

  void _measure(Size size) {
    if (_size == size) return;
    _size = size;
    _paths.clear();
    _metrics.clear();
    for (var i = 0; i < routes.length; i++) {
      final y = size.height * (i + 0.5) / routes.length;
      final path = Path();
      if (vertical) {
        path
          ..moveTo(0, 0)
          ..lineTo(0, y)
          ..lineTo(12, y);
      } else {
        path
          ..moveTo(engineWidth, size.height / 2)
          ..cubicTo(
            engineWidth + wireWidth * 0.65,
            size.height / 2,
            engineWidth + wireWidth * 0.35,
            y,
            engineWidth + wireWidth,
            y,
          );
      }
      _paths.add(path);
      _metrics.add(path.computeMetrics().first);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    _measure(size);
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final dot = Paint();
    for (var i = 0; i < routes.length; i++) {
      final (color, active) = routes[i];
      canvas.drawPath(
        _paths[i],
        line..color = color.withValues(alpha: active ? 0.6 : 0.25),
      );
      if (!active) continue;
      final metric = _metrics[i];
      for (var particle = 0; particle < 2; particle++) {
        final progress = (phase.value + particle / 2 + i * 0.13) % 1;
        final position = metric.getTangentForOffset(metric.length * progress);
        if (position == null) continue;
        canvas.drawCircle(
          position.position,
          4,
          dot..color = color.withValues(alpha: 0.15),
        );
        canvas.drawCircle(position.position, 1.8, dot..color = color);
      }
    }
  }

  @override
  bool shouldRepaint(_RouteFlowPainter oldDelegate) =>
      phase != oldDelegate.phase ||
      !listEquals(routes, oldDelegate.routes) ||
      vertical != oldDelegate.vertical ||
      engineWidth != oldDelegate.engineWidth ||
      wireWidth != oldDelegate.wireWidth;
}
