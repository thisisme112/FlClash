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
    required this.bottom,
    required this.cloud,
    required this.shade,
    required this.smokeShade,
    required this.sun,
  });

  static const day = _Sky(
    top: Color(0xFF2C7BE5),
    bottom: Color(0xFFA8D5FF),
    cloud: Color(0xFFFFFFFF),
    shade: Color(0xFFCFE0F2),
    smokeShade: Color(0xFFD3DEEA),
    sun: Color(0xFFFFE29A),
  );

  static const dusk = _Sky(
    top: Color(0xFF0E2F66),
    bottom: Color(0xFF4479BF),
    cloud: Color(0xFFE6EEF8),
    shade: Color(0xFF9DB3CF),
    smokeShade: Color(0xFFA7B9CE),
    sun: Color(0xFFFFD98A),
  );

  static _Sky of(Brightness brightness) =>
      brightness == Brightness.dark ? dusk : day;

  final Color top;
  final Color bottom;
  final Color cloud;
  final Color shade;
  final Color smokeShade;
  final Color sun;
}

const _hull = [
  Color(0xFF8E9BAD),
  Color(0xFFDCE3EC),
  Color(0xFFFFFFFF),
  Color(0xFFE4E9F0),
  Color(0xFF9AA6B7),
];
const _livery = [
  Color(0xFF9E2620),
  Color(0xFFE2463C),
  Color(0xFFFF7B6F),
  Color(0xFFE0453B),
  Color(0xFF962520),
];
const _finLit = [Color(0xFFF25A4F), Color(0xFFC9362E)];
const _finShade = [Color(0xFFC43A31), Color(0xFF8F231D)];
const _metal = [Color(0xFF4F5967), Color(0xFFB3BDCA), Color(0xFF5E6876)];
const _glass = [Color(0xFFD6EEFF), Color(0xFF4A8FE0), Color(0xFF1B4A8E)];
const _glint = Color(0xD9FFFFFF);
const _panelLine = Color(0x2E0F2440);
const _padRing = Color(0xCCFFFFFF);
const _padFill = Color(0x33FFFFFF);

/// Clouds parked in the idle sky: where, as fractions of the screen, and how
/// big, as a fraction of the screen's width.
const _skyClouds = [
  (0.26, 0.13, 0.46),
  (0.8, 0.27, 0.33),
  (0.3, 0.46, 0.28),
  (0.74, 0.6, 0.4),
  (0.2, 0.75, 0.31),
];

/// One cloud's puffs, relative to its width.
const _cloudPuffs = [
  (-0.34, 0.07, 0.19),
  (-0.15, -0.05, 0.26),
  (0.09, -0.12, 0.31),
  (0.31, 0.0, 0.22),
  (0.02, 0.08, 0.23),
  (-0.2, 0.11, 0.17),
  (0.2, 0.11, 0.18),
];

/// A fixed scatter in [0, 1): the same picture every time, with no Random.
double _scatter(int index, double seed) => (index * 0.618034 + seed) % 1;

/// A horizontal gradient spread evenly over [colors], for shading a round
/// part lit from one side.
Paint _across(double from, double to, List<Color> colors) => Paint()
  ..shader = ui.Gradient.linear(Offset(from, 0), Offset(to, 0), colors, [
    for (var index = 0; index < colors.length; index++)
      index / (colors.length - 1),
  ]);

/// A white puff lit from above: a cool shadow under it, the bright body on top.
void _paintPuff(
  Canvas canvas,
  Offset center,
  double radius,
  Color body,
  Color shade, [
  double alpha = 1,
]) {
  if (alpha <= 0 || radius <= 0) {
    return;
  }
  canvas
    ..drawCircle(
      center + Offset(0, radius * 0.22),
      radius,
      Paint()..color = shade.withValues(alpha: alpha),
    )
    ..drawCircle(
      center,
      radius * 0.96,
      Paint()..color = body.withValues(alpha: alpha),
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
      reach,
      Paint()..color = _padFill.withValues(alpha: _padFill.a * fade),
    )
    ..drawCircle(
      center,
      reach - 1,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = _padRing.withValues(alpha: _padRing.a * fade),
    );
}

void _paintFlame(
  Canvas canvas,
  double l,
  double hw,
  double thrust,
  double flicker,
) {
  final nozzle = l * 0.34;
  final reach = l * (0.35 + 0.75 * thrust) * flicker;
  final glow = l * 0.5 * thrust;
  canvas.drawCircle(
    Offset(0, nozzle),
    glow,
    Paint()
      ..shader = ui.Gradient.radial(Offset(0, nozzle), glow, const [
        Color(0x8CFFC460),
        Color(0x00FF9632),
      ]),
  );
  void plume(
    double width,
    double length,
    List<Color> colors,
    List<double> stops,
  ) {
    final w = hw * width;
    canvas.drawPath(
      Path()
        ..moveTo(-w, nozzle)
        ..cubicTo(
          -w * 1.25,
          nozzle + length * 0.35,
          -w * 0.5,
          nozzle + length * 0.8,
          0,
          nozzle + length,
        )
        ..cubicTo(
          w * 0.5,
          nozzle + length * 0.8,
          w * 1.25,
          nozzle + length * 0.35,
          w,
          nozzle,
        )
        ..close(),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, nozzle),
          Offset(0, nozzle + length),
          colors,
          stops,
        ),
    );
  }

  plume(
    0.95,
    reach,
    const [Color(0xFFFFAA46), Color(0xD9FF6E28), Color(0x00FF501E)],
    const [0, 0.45, 1],
  );
  plume(
    0.62,
    reach * 0.68,
    const [Color(0xFFFFF4BE), Color(0xE6FFCD5A), Color(0x00FFAA3C)],
    const [0, 0.55, 1],
  );
  plume(
    0.32,
    reach * 0.4,
    const [Color(0xFFFFFFFF), Color(0x00FFFAE1)],
    const [0, 1],
  );
}

/// A white rocket with a red livery, drawn nose-up around its middle and then
/// turned to [heading]; [thrust] lights the engine.
void _paintRocket(
  Canvas canvas, {
  required Offset center,
  required double length,
  required double heading,
  double thrust = 0,
  double flicker = 1,
}) {
  final l = length;
  final hw = l * 0.15;
  final base = l * 0.26;
  canvas
    ..save()
    ..translate(center.dx, center.dy)
    ..rotate(heading);
  if (thrust > 0) {
    _paintFlame(canvas, l, hw, thrust, flicker);
  }
  for (final side in const [-1.0, 1.0]) {
    canvas.drawPath(
      Path()
        ..moveTo(side * hw * 0.85, -l * 0.02)
        ..quadraticBezierTo(
          side * hw * 2.3,
          l * 0.13,
          side * hw * 2.2,
          l * 0.39,
        )
        ..lineTo(side * hw * 1.5, l * 0.33)
        ..quadraticBezierTo(
          side * hw * 1.05,
          l * 0.28,
          side * hw * 0.85,
          l * 0.27,
        )
        ..close(),
      _across(
        side * hw * 0.85,
        side * hw * 2.3,
        side < 0 ? _finLit : _finShade,
      ),
    );
  }
  canvas.drawPath(
    Path()
      ..moveTo(-hw * 0.6, base - 1)
      ..lineTo(hw * 0.6, base - 1)
      ..lineTo(hw * 0.8, l * 0.35)
      ..lineTo(-hw * 0.8, l * 0.35)
      ..close(),
    _across(-hw * 0.8, hw * 0.8, _metal),
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
  final livery = _across(-hw, hw, _livery);
  canvas
    ..drawPath(body, _across(-hw, hw, _hull))
    ..save()
    ..clipPath(body)
    ..drawRect(Rect.fromLTWH(-hw, -l * 0.5, hw * 2, l * 0.21), livery)
    ..drawRect(Rect.fromLTWH(-hw, l * 0.07, hw * 2, l * 0.05), livery)
    ..drawRect(
      Rect.fromLTWH(-hw, -l * 0.29, hw * 2, l * 0.008),
      Paint()..color = _panelLine,
    )
    ..restore()
    ..drawPath(
      Path()
        ..moveTo(-hw * 0.17, l * 0.1)
        ..lineTo(hw * 0.17, l * 0.1)
        ..lineTo(hw * 0.17, l * 0.38)
        ..quadraticBezierTo(0, l * 0.43, -hw * 0.17, l * 0.38)
        ..close(),
      _across(-hw * 0.17, hw * 0.17, _finShade),
    );
  final window = Offset(0, -l * 0.1);
  canvas
    ..drawCircle(window, hw * 0.58, _across(-hw * 0.58, hw * 0.58, _metal))
    ..drawCircle(
      window,
      hw * 0.44,
      Paint()
        ..shader = ui.Gradient.radial(
          window,
          hw * 0.44,
          _glass,
          const [0, 0.45, 1],
          TileMode.clamp,
          null,
          window + Offset(-hw * 0.16, -hw * 0.16),
          hw * 0.02,
        ),
    )
    ..save()
    ..translate(window.dx - hw * 0.15, window.dy - hw * 0.17)
    ..rotate(-0.6)
    ..drawOval(
      Rect.fromCenter(center: Offset.zero, width: hw * 0.28, height: hw * 0.14),
      Paint()..color = _glint,
    )
    ..restore()
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
    final skyPaint = Paint()
      ..shader = ui.Gradient.linear(Offset.zero, Offset(0, size.height), [
        sky.top,
        sky.bottom,
      ]);
    _paintBeam(canvas, wake);
    for (final side in const [-1.0, 1.0]) {
      _paintSkyHalf(canvas, size, wake, skyPaint, side);
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
            sky.sun.withValues(alpha: 0),
            sky.sun.withValues(alpha: 0.8 * glow),
            sky.sun.withValues(alpha: 0),
          ],
          const [0, 0.5, 1],
        ),
    );
  }

  void _paintSkyHalf(
    Canvas canvas,
    Size size,
    _Wake wake,
    Paint skyPaint,
    double side,
  ) {
    final far = wake.halfSpan * 4;
    final farEnd = wake.at(wake.halfSpan * 2, side * far);
    final farStart = wake.at(-wake.halfSpan * 2, side * far);
    final half = _edgePath(wake, side)
      ..lineTo(farEnd.dx, farEnd.dy)
      ..lineTo(farStart.dx, farStart.dy)
      ..close();
    canvas
      ..drawPath(half, skyPaint)
      ..save()
      ..clipPath(half);
    // Every cloud is drawn in both halves, each moved with its own half, so
    // one lying across the wake is torn in two.
    for (final (x, y, width) in _skyClouds) {
      final center = Offset(x * size.width, y * size.height);
      final shift = side * wake.gapAt(wake.distanceOf(center));
      _paintSkyCloud(canvas, center + wake.across * shift, width * size.width);
    }
    canvas.restore();
    if (wake.parting <= 0) {
      return;
    }
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
      _paintPuff(
        canvas,
        wake.at(s + _scallopGap * 0.5, side * (gap + radius * 1.25)),
        radius * 1.3,
        sky.cloud,
        sky.shade,
        shown,
      );
      final center = wake.at(s, side * (gap + radius * 0.35));
      rim.color = sky.sun.withValues(alpha: 0.75 * shown);
      canvas.drawCircle(center, radius, rim);
      _paintPuff(
        canvas,
        center + wake.across * side * 2.5,
        radius,
        sky.cloud,
        sky.shade,
        shown,
      );
    }
  }

  void _paintSkyCloud(Canvas canvas, Offset center, double width) {
    final shade = Paint()..color = sky.shade;
    final cloud = Paint()..color = sky.cloud;
    for (final (x, y, radius) in _cloudPuffs) {
      canvas.drawCircle(
        center + Offset(x, y + radius * 0.22) * width,
        radius * width,
        shade,
      );
    }
    for (final (x, y, radius) in _cloudPuffs) {
      canvas.drawCircle(
        center + Offset(x, y) * width,
        radius * width * 0.96,
        cloud,
      );
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
    for (var index = 0; index < _padSmokePuffs; index++) {
      final side = index.isEven ? 1.0 : -1.0;
      final reach = (index ~/ 2 + 1) * width * 0.8 * launch;
      _paintPuff(
        canvas,
        wake.at(restS - width, side * (reach + wake.gapAt(restS))),
        width * (0.7 + 0.6 * launch),
        sky.cloud,
        sky.smokeShade,
        0.95 * (1 - padOpen),
      );
    }
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
      _paintPuff(
        canvas,
        wake.at(s, side * (drift + wake.gapAt(s) + open * radius)),
        radius,
        sky.cloud,
        sky.smokeShade,
        0.95 * (1 - open),
      );
    }
  }

  void _paintWave(Canvas canvas, Size size, _Wake wake) {
    if (progress <= _wave.begin || progress >= _wave.end) {
      return;
    }
    final wave = _wave.transform(progress);
    canvas.drawCircle(
      wake.center,
      wave * size.longestSide * 0.75,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 + 16 * (1 - wave)
        ..color = sky.cloud.withValues(alpha: 0.5 * (1 - wave)),
    );
  }

  void _paintFlyingRocket(Canvas canvas, _Wake wake, Offset end) {
    final flown = _flight.transform(progress);
    if (flown >= 1) {
      return;
    }
    final launch = _ignite.transform(progress);
    final settling = (1 - flown * 50).clamp(0.0, 1.0);
    final shake =
        wake.across * math.sin(progress * 900) * _shake * launch * settling;
    _paintRocket(
      canvas,
      center: Offset.lerp(rest, end, flown)! + shake,
      length: _rocketLength * (1 - (1 - _farScale) * flown),
      heading: _headingOf(course),
      thrust: launch,
      flicker: 0.9 + 0.1 * math.sin(progress * 160),
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
