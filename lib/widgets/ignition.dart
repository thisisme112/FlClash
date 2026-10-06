import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:material_ui/material_ui.dart';

const _igniteDuration = Duration(milliseconds: 1100);
const _fadeDuration = Duration(milliseconds: 320);
const _burstEnd = 0.7;
const _particleCount = 40;
const _restingScale = 0.96;
const _colorCurve = Interval(0.12, 0.6, curve: Curves.easeOut);
const _entranceCurve = Interval(0.3, 1, curve: Curves.easeOutBack);

/// Shows [child] in grayscale until [active], then sets it off: a burst of
/// sparks from [origin], color flooding back, and the child settling in.
class Ignition extends StatefulWidget {
  const Ignition({
    super.key,
    required this.active,
    required this.origin,
    required this.child,
  });

  final bool active;

  /// Where the sparks start, as a fraction of the child's size.
  final Alignment origin;

  final Widget child;

  @override
  State<Ignition> createState() => _IgnitionState();
}

class _IgnitionState extends State<Ignition>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: _igniteDuration,
    reverseDuration: _fadeDuration,
    value: widget.active ? 1 : 0,
  );

  @override
  void didUpdateWidget(Ignition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active == widget.active) {
      return;
    }
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = widget.active ? 1 : 0;
    } else if (widget.active) {
      _controller.forward(from: 0);
    } else {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final sparks = [
      colorScheme.primary,
      colorScheme.tertiary,
      colorScheme.error,
      colorScheme.primaryContainer,
      colorScheme.onSurface,
    ];
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        final igniting = _controller.status == AnimationStatus.forward;
        final entrance = igniting ? _entranceCurve.transform(t) : 1.0;
        return Stack(
          fit: StackFit.expand,
          children: [
            // ponytail: a stopped app scrolls under a full-screen filter
            // layer; swap for a gray ColorScheme if that ever drops frames.
            _Saturation(
              saturation: igniting ? _colorCurve.transform(t) : t,
              child: Transform.scale(
                scale: _restingScale + (1 - _restingScale) * entrance,
                child: child,
              ),
            ),
            if (igniting && t < _burstEnd)
              IgnorePointer(
                child: CustomPaint(
                  painter: _BurstPainter(
                    progress: t / _burstEnd,
                    origin: widget.origin,
                    colors: sparks,
                  ),
                ),
              ),
          ],
        );
      },
      child: widget.child,
    );
  }
}

class _Saturation extends SingleChildRenderObjectWidget {
  const _Saturation({required this.saturation, super.child});

  final double saturation;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderSaturation(saturation);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderSaturation renderObject,
  ) {
    renderObject.saturation = saturation;
  }
}

/// Costs a layer only while desaturated, so a running app paints as before.
class _RenderSaturation extends RenderProxyBox {
  _RenderSaturation(this._saturation);

  double _saturation;

  set saturation(double value) {
    if (value == _saturation) {
      return;
    }
    final layered = alwaysNeedsCompositing;
    _saturation = value;
    if (layered != alwaysNeedsCompositing) {
      markNeedsCompositingBitsUpdate();
    }
    markNeedsPaint();
  }

  @override
  bool get alwaysNeedsCompositing => child != null && _saturation < 1;

  ColorFilter get _filter {
    final gray = 1 - _saturation;
    const r = 0.2126, g = 0.7152, b = 0.0722;
    return ColorFilter.matrix(<double>[
      r * gray + _saturation,
      g * gray,
      b * gray,
      0,
      0,
      r * gray,
      g * gray + _saturation,
      b * gray,
      0,
      0,
      r * gray,
      g * gray,
      b * gray + _saturation,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
    ]);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child == null) {
      return;
    }
    if (_saturation >= 1) {
      layer = null;
      super.paint(context, offset);
      return;
    }
    layer = context.pushColorFilter(
      offset,
      _filter,
      super.paint,
      oldLayer: layer as ColorFilterLayer?,
    );
  }
}

class _BurstPainter extends CustomPainter {
  _BurstPainter({
    required this.progress,
    required this.origin,
    required this.colors,
  });

  final double progress;
  final Alignment origin;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final center = origin.alongSize(size);
    final reach = size.longestSide * 0.85;
    final spread = Curves.easeOutCubic.transform(progress);
    final fade = 1 - progress;
    final paint = Paint();
    for (var index = 0; index < _particleCount; index++) {
      // A fixed scatter: the same burst every time, with no Random to seed.
      final jitter = (index * 0.618034) % 1;
      final angle = (index + jitter) / _particleCount * 2 * math.pi;
      final distance = reach * (0.35 + 0.65 * jitter) * spread;
      paint.color = colors[index % colors.length].withValues(alpha: fade);
      canvas.drawCircle(
        center + Offset(math.cos(angle), math.sin(angle)) * distance,
        2 + 4 * fade * (0.5 + jitter),
        paint,
      );
    }
    canvas.drawCircle(
      center,
      reach * spread,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 + 10 * fade
        ..color = colors.first.withValues(alpha: fade * 0.6),
    );
  }

  @override
  bool shouldRepaint(_BurstPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.origin != origin;
  }
}
