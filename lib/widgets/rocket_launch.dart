import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'navigation_dock.dart';

const _launchDuration = Duration(milliseconds: 1800);
const _landDuration = Duration(milliseconds: 900);
const _ignite = Interval(0, 0.12, curve: Curves.easeOut);
const _flight = Interval(0.05, 0.42, curve: Curves.easeInCubic);
const _parting = Interval(0.34, 1);
const _beam = Interval(0.34, 0.8, curve: Curves.easeOut);
const _wave = Interval(0.34, 0.85, curve: Curves.easeOutCubic);
const _settle = Interval(0.34, 1, curve: Curves.easeOutCubic);
const _tearStart = 0.1;
const _tearSpeed = 3.2;
const _gapOvershoot = 1.3;
const _revealZoom = 0.06;
const _farScale = 0.55;
const _shake = 1.6;
const _rocketToPad = 1.7;
const _trailPuffs = 36;
const _padSmokePuffs = 6;
const _scallopGap = 26.0;
const _seamStep = 12.0;
// Halves that only meet would leave an antialiased hairline along the wake.
const _seamOverlap = 1.0;

/// Keeps [child] under a blue sky with only a rocket on its pad until
/// [launched]. The rocket then lifts off toward the upper start corner, and
/// the sky tears open along its contrail as the clouds roll aside; turning
/// [launched] off closes the sky and lands the rocket again.
class RocketLaunch extends StatefulWidget {
  const RocketLaunch({
    super.key,
    required this.launched,
    required this.onLaunch,
    required this.restInset,
    required this.padRadius,
    required this.label,
    required this.peekLabel,
    required this.child,
  });

  final bool launched;
  final VoidCallback onLaunch;

  /// The pad's center, measured from the bottom-end corner.
  final Offset restInset;

  final double padRadius;
  final String label;

  /// Names the long press, which opens the cover without starting.
  final String peekLabel;

  final Widget child;

  @override
  State<RocketLaunch> createState() => _RocketLaunchState();
}

class _RocketLaunchState extends State<RocketLaunch>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: _launchDuration,
    reverseDuration: _landDuration,
    value: widget.launched ? 1 : 0,
  );
  bool _peeking = false;

  bool get _open => widget.launched || _peeking;

  @override
  void didUpdateWidget(RocketLaunch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.launched == widget.launched) {
      return;
    }
    final wasOpen = oldWidget.launched || _peeking;
    _peeking = false;
    _animate(wasOpen);
  }

  void _peek() {
    setState(() => _peeking = true);
    _animate(false);
  }

  void _animate(bool wasOpen) {
    if (wasOpen == _open) {
      return;
    }
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = _open ? 1 : 0;
    } else if (_open) {
      _controller.forward();
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
    final sky = _Sky.of(Theme.of(context).brightness);
    final course = _courseOf(Directionality.of(context));
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final inset = widget.restInset;
        final rest = Offset(
          course.dx > 0 ? inset.dx : size.width - inset.dx,
          size.height - inset.dy,
        );
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final t = _controller.value;
            final covered = _controller.isDismissed;
            final settled = _controller.isCompleted;
            return Stack(
              fit: StackFit.expand,
              children: [
                Offstage(
                  offstage: covered,
                  child: TickerMode(
                    enabled: !covered,
                    child: ExcludeFocus(
                      excluding: !settled,
                      child: IgnorePointer(
                        ignoring: !settled,
                        child: Transform.scale(
                          scale: 1 + _revealZoom * (1 - _settle.transform(t)),
                          child: child,
                        ),
                      ),
                    ),
                  ),
                ),
                if (!settled)
                  IgnorePointer(
                    child: CustomPaint(
                      painter: _LaunchPainter(
                        progress: t,
                        rest: rest,
                        course: course,
                        padRadius: widget.padRadius,
                        sky: sky,
                      ),
                    ),
                  ),
                if (covered)
                  Positioned(
                    left: rest.dx - widget.padRadius,
                    top: rest.dy - widget.padRadius,
                    width: widget.padRadius * 2,
                    height: widget.padRadius * 2,
                    child: _LaunchPad(
                      heading: _headingOf(course),
                      label: widget.label,
                      peekLabel: widget.peekLabel,
                      onLaunch: widget.onLaunch,
                      onPeek: _peek,
                    ),
                  ),
              ],
            );
          },
          child: widget.child,
        );
      },
    );
  }
}

/// Up and toward the start side at 45 degrees, whatever the screen's shape.
Offset _courseOf(TextDirection direction) =>
    Offset(direction == TextDirection.rtl ? 1 : -1, -1) / math.sqrt2;

/// Turns a rocket drawn nose-up to face [direction].
double _headingOf(Offset direction) => direction.direction + math.pi / 2;

class _LaunchPad extends StatelessWidget {
  const _LaunchPad({
    required this.heading,
    required this.label,
    required this.peekLabel,
    required this.onLaunch,
    required this.onPeek,
  });

  final double heading;
  final String label;
  final String peekLabel;
  final VoidCallback onLaunch;
  final VoidCallback onPeek;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      onLongPressHint: peekLabel,
      child: ElasticPress(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onLaunch,
          onLongPressStart: (_) => HapticFeedback.mediumImpact(),
          // The pad leaves the tree once the cover moves, so it must not
          // move while the finger is still on the pad.
          onLongPressEnd: (_) => onPeek(),
          child: CustomPaint(painter: _PadPainter(heading: heading)),
        ),
      ),
    );
  }
}

/// The rocket alone, nose to the upper start corner, at the size of an icon.
class RocketIcon extends StatelessWidget {
  const RocketIcon({super.key, this.size = 24});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _IconPainter(
          heading: _headingOf(_courseOf(Directionality.of(context))),
        ),
      ),
    );
  }
}

/// The sky the rocket waits in, kept blue whatever the app's colors; a dark
/// app gets a dusk one so the screen does not flare at night.
class _Sky {
  const _Sky({
    required this.top,
    required this.mid,
    required this.low,
    required this.deep,
    required this.shadow,
    required this.body,
    required this.light,
    required this.rim,
    required this.sun,
  });

  static const day = _Sky(
    top: Color(0xFF1546B5),
    mid: Color(0xFF3A87EC),
    low: Color(0xFFA6DCF8),
    deep: Color(0xFF8193D2),
    shadow: Color(0xFFA7B8E6),
    body: Color(0xFFE4ECFB),
    light: Color(0xFFFFFFFF),
    rim: Color(0xFFFFE3A3),
    sun: Color(0xFFFFF4D6),
  );

  static const dusk = _Sky(
    top: Color(0xFF0B1E52),
    mid: Color(0xFF24509E),
    low: Color(0xFF7393CE),
    deep: Color(0xFF55609A),
    shadow: Color(0xFF6C79AE),
    body: Color(0xFFC9D2EC),
    light: Color(0xFFF2F4FB),
    rim: Color(0xFFFFC98A),
    sun: Color(0xFFFFE0B0),
  );

  static _Sky of(Brightness brightness) =>
      brightness == Brightness.dark ? dusk : day;

  final Color top;
  final Color mid;
  final Color low;
  final Color deep;
  final Color shadow;
  final Color body;
  final Color light;
  final Color rim;
  final Color sun;
}

const _ink = Color(0xFF1A2340);
const _hull = Color(0xFFEEF3FA);
const _hullLit = Color(0xFFFFFFFF);
const _hullShade = Color(0xFFAFC0DD);
const _hullDeep = Color(0xFF8597BE);
const _red = Color(0xFFE8414A);
const _redShade = Color(0xFFA8233A);
const _redLit = Color(0xFFFF9A96);
const _metal = Color(0xFF8C9AB6);
const _metalShade = Color(0xFF56627E);
const _frame = Color(0xFFDCE4F0);
const _frameShade = Color(0xFF8D9CBB);
const _glass = Color(0xFF1E3F8E);
const _glassGlow = Color(0xFF2F64C8);
const _glint = Color(0xFFFFFFFF);
const _flameOuter = Color(0xFFFF6A2B);
const _flameMid = Color(0xFFFFC23D);
const _flameCore = Color(0xFFFFF8DC);
const _spark = Color(0xFFFFC85A);
const _white = Color(0xFFFFFFFF);

/// Where the sun sits, so every cel band is cut on the same side.
const _light = Offset(0.62, -0.78);

/// The idle sky's sparkles: where, as fractions of the screen, and how big.
const _sparkles = [
  (0.36, 0.1, 5.0),
  (0.55, 0.24, 3.5),
  (0.12, 0.42, 4.0),
  (0.48, 0.52, 3.0),
  (0.9, 0.42, 4.5),
];

/// The idle sky's clouds as puffs: where, as fractions of the screen, and how
/// big, as a fraction of its width. A towering bank rises along the foot.
final _skyPuffs = [
  for (var index = 0; index < 11; index++)
    (
      -0.08 + index * 0.12,
      0.97 - 0.03 * _scatter(index, 0.2),
      0.15 + 0.08 * _scatter(index, 0.5),
    ),
  (0.1, 0.86, 0.17),
  (0.24, 0.84, 0.14),
  (0.06, 0.77, 0.14),
  (0.19, 0.74, 0.12),
  (0.11, 0.68, 0.1),
  (0.22, 0.66, 0.08),
  (0.15, 0.62, 0.07),
  (0.4, 0.9, 0.12),
  (0.6, 0.91, 0.11),
  (0.92, 0.86, 0.13),
  (0.62, 0.36, 0.07),
  (0.7, 0.33, 0.09),
  (0.79, 0.35, 0.065),
  (0.7, 0.37, 0.06),
  (0.18, 0.2, 0.05),
  (0.25, 0.185, 0.065),
  (0.32, 0.2, 0.05),
  (0.86, 0.56, 0.05),
  (0.92, 0.545, 0.06),
  (0.97, 0.56, 0.045),
];

/// A fixed scatter in [0, 1): the same picture every time, with no Random.
double _scatter(int index, double seed) => (index * 0.618034 + seed) % 1;

typedef _Puff = ({Offset center, double radius, double alpha});

/// A cel-shaded cloud: every puff's band is laid down before the next band,
/// so overlapping puffs merge into one mass with hard-edged tones.
void _paintCumulus(Canvas canvas, List<_Puff> puffs, _Sky sky) {
  final paint = Paint();
  void band(Color color, double shift, double scale) {
    for (final puff in puffs) {
      if (puff.alpha <= 0 || puff.radius <= 0) {
        continue;
      }
      paint.color = color.withValues(alpha: puff.alpha);
      canvas.drawCircle(
        puff.center + _light * (puff.radius * shift),
        puff.radius * scale,
        paint,
      );
    }
  }

  band(sky.deep, -0.1, 0.98);
  band(sky.shadow, 0, 0.97);
  band(sky.body, 0.11, 0.9);
  band(sky.light, 0.3, 0.6);
}

void _paintSparkle(Canvas canvas, Offset center, double radius, double alpha) {
  final star = Path();
  for (var index = 0; index < 8; index++) {
    final reach = index.isEven ? radius : radius * 0.18;
    final point = center + Offset.fromDirection(index * math.pi / 4, reach);
    index == 0
        ? star.moveTo(point.dx, point.dy)
        : star.lineTo(point.dx, point.dy);
  }
  canvas.drawPath(
    star..close(),
    Paint()..color = _white.withValues(alpha: alpha),
  );
}

void _paintPad(
  Canvas canvas,
  Offset center,
  double radius, {
  double spread = 0,
}) {
  final fade = 1 - spread;
  if (fade <= 0) {
    return;
  }
  final reach = radius * (1 + 0.6 * spread);
  canvas
    ..drawCircle(
      center,
      reach * 1.15,
      Paint()
        ..shader = ui.Gradient.radial(
          center,
          reach * 1.15,
          [
            _white.withValues(alpha: 0),
            _white.withValues(alpha: 0.35 * fade),
            _white.withValues(alpha: 0),
          ],
          const [0.48, 0.84, 1],
        ),
    )
    ..drawCircle(
      center,
      reach - 1.5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = _white.withValues(alpha: 0.9 * fade),
    );
  _paintSparkle(canvas, center + Offset(reach * 0.72, -reach * 0.72), 5, fade);
}

void _paintFlame(
  Canvas canvas,
  double l,
  double hw,
  double thrust,
  double flicker,
  double time,
) {
  final nozzle = l * 0.34;
  final reach = l * (0.4 + 0.8 * thrust) * flicker;
  final glow = l * 0.55 * thrust;
  canvas.drawCircle(
    Offset(0, nozzle),
    glow,
    Paint()
      ..shader = ui.Gradient.radial(Offset(0, nozzle), glow, const [
        Color(0x99FFD678),
        Color(0x00FF963C),
      ]),
  );
  void tongue(double width, double length, Color color, double sway) {
    final w = hw * width;
    canvas.drawPath(
      Path()
        ..moveTo(-w, nozzle)
        ..cubicTo(
          -w * 1.15,
          nozzle + length * 0.3,
          -w * 0.35 + sway,
          nozzle + length * 0.72,
          sway,
          nozzle + length,
        )
        ..cubicTo(
          w * 0.35 + sway,
          nozzle + length * 0.72,
          w * 1.15,
          nozzle + length * 0.3,
          w,
          nozzle,
        )
        ..close(),
      Paint()..color = color,
    );
  }

  final sway = math.sin(time * 220) * hw * 0.12;
  tongue(1, reach, _flameOuter, sway);
  tongue(0.5, reach * 0.55, _flameOuter, -hw * 0.75 + sway * 0.5);
  tongue(0.5, reach * 0.5, _flameOuter, hw * 0.75 - sway * 0.5);
  tongue(0.7, reach * 0.72, _flameMid, -sway * 0.6);
  tongue(0.38, reach * 0.42, _flameCore, sway * 0.3);
  final spark = Paint();
  for (var index = 0; index < 5; index++) {
    final age = (_scatter(index, 0.4) + time * 6) % 1;
    spark.color = _spark.withValues(alpha: (1 - age) * thrust);
    canvas.drawCircle(
      Offset(
        (_scatter(index, 0.9) - 0.5) * hw * 1.6,
        nozzle + reach * (0.6 + age * 0.9),
      ),
      hw * 0.12 * (1 - age),
      spark,
    );
  }
}

/// A cel-shaded white rocket with a red livery and an inked outline, drawn
/// nose-up around its middle and turned to [heading]. Its lit side is +x,
/// which faces the sun once it points up and toward the start side.
void _paintRocket(
  Canvas canvas, {
  required Offset center,
  required double length,
  required double heading,
  double thrust = 0,
  double flicker = 1,
  double time = 0,
}) {
  final l = length;
  final hw = l * 0.15;
  final base = l * 0.26;
  final ink = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = l * 0.022
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round
    ..color = _ink;
  void shaded(Path path, Color fill, void Function() bands) {
    canvas
      ..drawPath(path, Paint()..color = fill)
      ..save()
      ..clipPath(path);
    bands();
    canvas
      ..restore()
      ..drawPath(path, ink);
  }

  canvas
    ..save()
    ..translate(center.dx, center.dy)
    ..rotate(heading);
  if (thrust > 0) {
    _paintFlame(canvas, l, hw, thrust, flicker, time);
  }
  for (final side in const [-1.0, 1.0]) {
    final fin = Path()
      ..moveTo(side * hw * 0.85, -l * 0.02)
      ..quadraticBezierTo(side * hw * 2.3, l * 0.13, side * hw * 2.2, l * 0.39)
      ..lineTo(side * hw * 1.5, l * 0.33)
      ..quadraticBezierTo(
        side * hw * 1.05,
        l * 0.28,
        side * hw * 0.85,
        l * 0.27,
      )
      ..close();
    shaded(fin, side > 0 ? _red : _redShade, () {
      if (side > 0) {
        canvas.drawPath(
          Path()
            ..moveTo(hw * 0.95, 0)
            ..quadraticBezierTo(hw * 2.18, l * 0.14, hw * 2.08, l * 0.36),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = l * 0.03
            ..color = _redLit,
        );
      }
    });
  }
  shaded(
    Path()
      ..moveTo(-hw * 0.6, base - 1)
      ..lineTo(hw * 0.6, base - 1)
      ..lineTo(hw * 0.8, l * 0.35)
      ..lineTo(-hw * 0.8, l * 0.35)
      ..close(),
    _metal,
    () => canvas.drawRect(
      Rect.fromLTWH(-hw, base - 2, hw * 0.75, l * 0.12),
      Paint()..color = _metalShade,
    ),
  );
  final body = Path()
    ..moveTo(0, -l * 0.5)
    ..cubicTo(hw * 0.62, -l * 0.44, hw, -l * 0.3, hw, -l * 0.12)
    ..lineTo(hw, l * 0.17)
    ..quadraticBezierTo(hw, base, hw * 0.82, base)
    ..lineTo(-hw * 0.82, base)
    ..quadraticBezierTo(-hw, base, -hw, l * 0.17)
    ..lineTo(-hw, -l * 0.12)
    ..cubicTo(-hw, -l * 0.3, -hw * 0.62, -l * 0.44, 0, -l * 0.5)
    ..close();
  shaded(body, _hull, () {
    void livery(double top, double bottom) {
      canvas
        ..drawRect(Rect.fromLTRB(-hw, top, hw, bottom), Paint()..color = _red)
        ..drawRect(
          Rect.fromLTRB(-hw, top, -hw * 0.22, bottom),
          Paint()..color = _redShade,
        );
    }

    canvas
      ..drawRect(
        Rect.fromLTRB(-hw, -l * 0.5, -hw * 0.22, l * 0.5),
        Paint()..color = _hullShade,
      )
      ..drawRect(
        Rect.fromLTRB(-hw, -l * 0.5, -hw * 0.76, l * 0.5),
        Paint()..color = _hullDeep,
      );
    livery(-l * 0.5, -l * 0.29);
    livery(l * 0.07, l * 0.12);
    canvas
      ..drawOval(
        Rect.fromCenter(
          center: Offset(hw * 0.52, -l * 0.08),
          width: hw * 0.24,
          height: l * 0.34,
        ),
        Paint()..color = _hullLit,
      )
      ..save()
      ..translate(hw * 0.38, -l * 0.37)
      ..rotate(0.25)
      ..drawOval(
        Rect.fromCenter(center: Offset.zero, width: hw * 0.2, height: l * 0.12),
        Paint()..color = _redLit,
      )
      ..restore();
  });
  shaded(
    Path()
      ..moveTo(-hw * 0.17, l * 0.1)
      ..lineTo(hw * 0.17, l * 0.1)
      ..lineTo(hw * 0.17, l * 0.38)
      ..quadraticBezierTo(0, l * 0.43, -hw * 0.17, l * 0.38)
      ..close(),
    _red,
    () => canvas.drawRect(
      Rect.fromLTWH(-hw * 0.2, l * 0.09, hw * 0.2, l * 0.36),
      Paint()..color = _redShade,
    ),
  );
  final window = Offset(0, -l * 0.1);
  final outer = hw * 0.6;
  final inner = hw * 0.43;
  shaded(
    Path()..addOval(Rect.fromCircle(center: window, radius: outer)),
    _frame,
    () => canvas.drawRect(
      Rect.fromLTWH(-outer, window.dy - outer, outer * 0.8, outer * 2),
      Paint()..color = _frameShade,
    ),
  );
  shaded(
    Path()..addOval(Rect.fromCircle(center: window, radius: inner)),
    _glass,
    () => canvas
      ..drawCircle(
        window + Offset(-inner * 0.35, inner * 0.4),
        inner * 0.75,
        Paint()..color = _glassGlow,
      )
      ..drawCircle(
        window + Offset(-inner * 0.15, inner * 0.18),
        inner * 0.72,
        Paint()..color = _glass,
      )
      ..drawArc(
        Rect.fromCircle(center: window, radius: inner * 0.72),
        -1.45,
        1.3,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = inner * 0.28
          ..color = _glint,
      ),
  );
  canvas
    ..drawCircle(
      window + Offset(inner * 0.15, inner * 0.32),
      inner * 0.11,
      Paint()..color = _glint,
    )
    ..restore();
}

class _PadPainter extends CustomPainter {
  const _PadPainter({required this.heading});

  final double heading;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    _paintPad(canvas, center, radius);
    _paintRocket(
      canvas,
      center: center,
      length: radius * _rocketToPad,
      heading: heading,
    );
  }

  @override
  bool shouldRepaint(_PadPainter oldDelegate) => oldDelegate.heading != heading;
}

class _IconPainter extends CustomPainter {
  const _IconPainter({required this.heading});

  final double heading;

  @override
  void paint(Canvas canvas, Size size) {
    _paintRocket(
      canvas,
      center: size.center(Offset.zero),
      length: size.shortestSide * 1.1,
      heading: heading,
    );
  }

  @override
  bool shouldRepaint(_IconPainter oldDelegate) =>
      oldDelegate.heading != heading;
}

/// The line the rocket flies along, and how far the cover has torn open
/// from it.
class _Wake {
  factory _Wake(Size size, Offset rest, Offset course, double progress) {
    final across = Offset(-course.dy, course.dx);
    final center =
        rest + course * _dot(size.center(Offset.zero) - rest, course);
    final farthest = [
      Offset.zero,
      Offset(size.width, 0),
      Offset(0, size.height),
      Offset(size.width, size.height),
    ].map((point) => _dot(point - center, across).abs()).reduce(math.max);
    return _Wake._(
      along: course,
      across: across,
      center: center,
      halfSpan: Offset(size.width, size.height).distance / 2,
      maxGap: farthest + _scallopGap * 1.4 + 8,
      parting: _parting.transform(progress),
    );
  }

  const _Wake._({
    required this.along,
    required this.across,
    required this.center,
    required this.halfSpan,
    required this.maxGap,
    required this.parting,
  });

  final Offset along;
  final Offset across;
  final Offset center;
  final double halfSpan;

  /// Enough for either half to clear the screen, scallops included.
  final double maxGap;
  final double parting;

  /// How far the cover has opened at [s] along the wake, 0 to about 1: a thin
  /// tear runs out from the middle, then widens into a lens.
  double openAt(double s) {
    final front = halfSpan * (_tearStart + _tearSpeed * parting);
    final x = s / front;
    final lens = math.sqrt(math.max(0, 1 - x * x));
    final width = parting * parting * (3 - 2 * parting);
    return width * lens;
  }

  double gapAt(double s) => openAt(s) * maxGap * _gapOvershoot;

  double distanceOf(Offset point) => _dot(point - center, along);

  Offset at(double s, double offset) => center + along * s + across * offset;

  /// Positions along the wake from well past one end of the screen to well
  /// past the other.
  Iterable<double> stations(double step) sync* {
    final count = (halfSpan * 4 / step).ceil();
    for (var index = 0; index <= count; index++) {
      yield -halfSpan * 2 + index * step;
    }
  }
}

double _dot(Offset a, Offset b) => a.dx * b.dx + a.dy * b.dy;

class _LaunchPainter extends CustomPainter {
  const _LaunchPainter({
    required this.progress,
    required this.rest,
    required this.course,
    required this.padRadius,
    required this.sky,
  });

  final double progress;
  final Offset rest;
  final Offset course;
  final double padRadius;
  final _Sky sky;

  double get _rocketLength => padRadius * _rocketToPad;

  /// Where the rocket is wholly off the screen.
  Offset _endOf(Size size) {
    final toSide = course.dx < 0 ? rest.dx : size.width - rest.dx;
    final exit = math.min(toSide / course.dx.abs(), rest.dy / course.dy.abs());
    return rest + course * (exit + _rocketLength * 1.5);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }
    final wake = _Wake(size, rest, course, progress);
    final end = _endOf(size);
    _paintBeam(canvas, wake);
    for (final side in const [-1.0, 1.0]) {
      _paintSkyHalf(canvas, size, wake, side);
    }
    _paintTrail(canvas, wake, end);
    _paintWave(canvas, size, wake);
    if (progress > 0) {
      _paintPad(canvas, rest, padRadius, spread: _ignite.transform(progress));
      _paintFlyingRocket(canvas, wake, end);
    }
  }

  Path _edgePath(_Wake wake, double side) {
    final path = Path();
    var first = true;
    for (final s in wake.stations(_seamStep)) {
      final point = wake.at(s, side * (wake.gapAt(s) - _seamOverlap));
      if (first) {
        path.moveTo(point.dx, point.dy);
        first = false;
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    return path;
  }

  /// Sunlight through the tear, brightest along the wake; the sky painted
  /// over it keeps it inside the gap.
  void _paintBeam(Canvas canvas, _Wake wake) {
    if (progress <= _beam.begin || progress >= _beam.end) {
      return;
    }
    final glow = 1 - _beam.transform(progress);
    final reach = wake.gapAt(0) + _scallopGap;
    canvas.drawRect(
      Offset.zero & Size.square(wake.halfSpan * 2),
      Paint()
        ..shader = ui.Gradient.linear(
          wake.at(0, -reach),
          wake.at(0, reach),
          [
            sky.rim.withValues(alpha: 0),
            sky.sun.withValues(alpha: 0.9 * glow),
            sky.rim.withValues(alpha: 0),
          ],
          const [0, 0.5, 1],
        ),
    );
  }

  void _paintSkyHalf(Canvas canvas, Size size, _Wake wake, double side) {
    final far = wake.halfSpan * 4;
    final farEnd = wake.at(wake.halfSpan * 2, side * far);
    final farStart = wake.at(-wake.halfSpan * 2, side * far);
    final half = _edgePath(wake, side)
      ..lineTo(farEnd.dx, farEnd.dy)
      ..lineTo(farStart.dx, farStart.dy)
      ..close();
    // Everything in the sky is drawn in both halves, each moved with its own
    // half, so a cloud lying across the wake is torn in two.
    Offset moved(Offset point) =>
        point + wake.across * (side * wake.gapAt(wake.distanceOf(point)));
    canvas
      ..save()
      ..clipPath(half);
    _paintSky(canvas, size, moved);
    canvas.restore();
    if (wake.parting <= 0) {
      return;
    }
    final billows = <_Puff>[];
    final rim = Paint();
    var index = 0;
    for (final s in wake.stations(_scallopGap)) {
      final open = wake.openAt(s);
      final jitter = _scatter(index++, side > 0 ? 0.2 : 0.55);
      if (open <= 0) {
        continue;
      }
      final gap = wake.gapAt(s);
      final shown = math.min(1.0, open * 4);
      final radius = _scallopGap * (0.6 + 0.55 * jitter) * (0.75 + 0.7 * open);
      billows.add((
        center: wake.at(s + _scallopGap * 0.5, side * (gap + radius * 1.25)),
        radius: radius * 1.3,
        alpha: shown,
      ));
      final center = wake.at(s, side * (gap + radius * 0.35));
      rim.color = sky.rim.withValues(alpha: 0.9 * shown);
      canvas.drawCircle(center - wake.across * side * 3, radius, rim);
      billows.add((center: center, radius: radius, alpha: shown));
    }
    _paintCumulus(canvas, billows, sky);
  }

  void _paintSky(Canvas canvas, Size size, Offset Function(Offset) moved) {
    final w = size.width;
    final h = size.height;
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(0, h),
          [sky.top, sky.mid, sky.low],
          const [0, 0.55, 1],
        ),
    );
    final sun = moved(Offset(w * 0.98, h * 0.02));
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.radial(
          sun,
          w * 0.75,
          [
            sky.sun.withValues(alpha: 0.95),
            sky.sun.withValues(alpha: 0.6),
            sky.sun.withValues(alpha: 0.12),
            sky.sun.withValues(alpha: 0),
          ],
          const [0, 0.12, 0.4, 1],
        ),
    );
    final ray = Paint()..color = sky.sun.withValues(alpha: 0.07);
    for (var index = 0; index < 7; index++) {
      final angle = math.pi * 0.55 + index * 0.12 + _scatter(index, 0.3) * 0.05;
      final spread = 0.025 + 0.02 * _scatter(index, 0.7);
      final from = sun + Offset.fromDirection(angle - spread, h * 1.4);
      final to = sun + Offset.fromDirection(angle + spread, h * 1.4);
      canvas.drawPath(
        Path()
          ..moveTo(sun.dx, sun.dy)
          ..lineTo(from.dx, from.dy)
          ..lineTo(to.dx, to.dy)
          ..close(),
        ray,
      );
    }
    final flareAim = Offset(w * 0.35, h * 0.5);
    for (final (along, radius, alpha) in const [
      (0.28, 0.05, 0.16),
      (0.42, 0.025, 0.22),
      (0.6, 0.09, 0.08),
      (0.72, 0.03, 0.18),
    ]) {
      canvas.drawCircle(
        sun + (flareAim - sun) * (along * 2),
        w * radius,
        Paint()..color = _white.withValues(alpha: alpha),
      );
    }
    _paintCumulus(canvas, [
      for (final (x, y, radius) in _skyPuffs)
        (center: moved(Offset(x * w, y * h)), radius: radius * w, alpha: 1.0),
    ], sky);
    for (final (x, y, radius) in _sparkles) {
      _paintSparkle(canvas, moved(Offset(x * w, y * h)), radius, 0.9);
    }
  }

  void _paintTrail(Canvas canvas, _Wake wake, Offset end) {
    final launch = _ignite.transform(progress);
    if (launch <= 0) {
      return;
    }
    final flown = _flight.transform(progress);
    final width = _rocketLength * 0.3;
    final restS = wake.distanceOf(rest);
    final pathLength = (end - rest).distance;
    final padOpen = wake.openAt(restS);
    final smoke = <_Puff>[
      for (var index = 0; index < _padSmokePuffs; index++)
        (
          center: wake.at(
            restS - width,
            (index.isEven ? 1 : -1) *
                ((index ~/ 2 + 1) * width * 0.8 * launch + wake.gapAt(restS)),
          ),
          radius: width * (0.7 + 0.6 * launch),
          alpha: 1 - padOpen,
        ),
    ];
    for (var index = 0; index < _trailPuffs; index++) {
      final along = index / _trailPuffs;
      if (flown <= along) {
        break;
      }
      final age = ((flown - along) * 2.5).clamp(0.0, 1.0);
      final s = restS + pathLength * along;
      final open = wake.openAt(s);
      final side = index.isEven ? 1.0 : -1.0;
      final perspective = 1 - (1 - _farScale) * along;
      final radius =
          width *
          (0.55 + 2 * age) *
          perspective *
          (0.8 + 0.4 * _scatter(index, 0.3));
      final drift = width * 0.4 * age * _scatter(index, 0.8);
      smoke.add((
        center: wake.at(s, side * (drift + wake.gapAt(s) + open * radius)),
        radius: radius,
        alpha: 1 - open,
      ));
    }
    _paintCumulus(canvas, smoke, sky);
  }

  void _paintWave(Canvas canvas, Size size, _Wake wake) {
    if (progress <= _wave.begin || progress >= _wave.end) {
      return;
    }
    final wave = _wave.transform(progress);
    for (final (lag, width, alpha) in const [
      (0.0, 14.0, 0.55),
      (0.12, 4.0, 0.8),
    ]) {
      final reach = (wave - lag).clamp(0.0, 1.0);
      if (reach <= 0) {
        continue;
      }
      canvas.drawCircle(
        wake.center,
        reach * size.longestSide * 0.75,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5 + width * (1 - reach)
          ..color = _white.withValues(alpha: alpha * (1 - reach)),
      );
    }
  }

  void _paintFlyingRocket(Canvas canvas, _Wake wake, Offset end) {
    final flown = _flight.transform(progress);
    if (flown >= 1) {
      return;
    }
    final launch = _ignite.transform(progress);
    final length = _rocketLength * (1 - (1 - _farScale) * flown);
    final position = Offset.lerp(rest, end, flown)!;
    final rush =
        (flown * 6).clamp(0.0, 1.0) * ((1 - flown) * 4).clamp(0.0, 1.0);
    if (rush > 0) {
      final line = Paint()
        ..strokeCap = StrokeCap.round
        ..color = _white.withValues(alpha: 0.75 * rush);
      for (var index = 0; index < 9; index++) {
        final start =
            position -
            course * (length * (0.5 + _scatter(index, 0.45) * 1.2)) +
            wake.across * ((_scatter(index, 0.15) - 0.5) * length * 1.8);
        final reach = length * (1.4 + 2.6 * _scatter(index, 0.75)) * rush;
        line.strokeWidth = 1 + _scatter(index, 0.33) * 1.5;
        canvas.drawLine(start, start - course * reach, line);
      }
    }
    final settling = (1 - flown * 50).clamp(0.0, 1.0);
    final shake =
        wake.across * math.sin(progress * 900) * _shake * launch * settling;
    _paintRocket(
      canvas,
      center: position + shake,
      length: length,
      heading: _headingOf(course),
      thrust: launch,
      flicker: 0.9 + 0.1 * math.sin(progress * 160),
      time: progress,
    );
  }

  @override
  bool shouldRepaint(_LaunchPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.rest != rest ||
      oldDelegate.course != course ||
      oldDelegate.padRadius != padRadius ||
      oldDelegate.sky != sky;
}
