import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:fl_clash/common/common.dart';
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
const _rocketToPad = 1.55;
const _trailPuffs = 36;
const _padSmokePuffs = 6;
const _scallopGap = 26.0;
const _seamStep = 12.0;
// Halves that only meet would leave an antialiased hairline along the wake.
const _seamOverlap = 1.0;

/// Keeps [child] under a plain cover with only a rocket on its pad until
/// [launched]. The rocket then lifts off toward the upper start corner, and
/// the cover tears open along its wake and rolls aside like parting clouds;
/// turning [launched] off closes the cover and lands the rocket again.
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
    final scheme = Theme.of(context).colorScheme;
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
                        scheme: scheme,
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
                      scheme: scheme,
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
    required this.scheme,
    required this.label,
    required this.peekLabel,
    required this.onLaunch,
    required this.onPeek,
  });

  final double heading;
  final ColorScheme scheme;
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
          child: CustomPaint(
            painter: _PadPainter(heading: heading, scheme: scheme),
          ),
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
          scheme: Theme.of(context).colorScheme,
        ),
      ),
    );
  }
}

class _LaunchColors {
  const _LaunchColors({
    required this.cloud,
    required this.cloudShade,
    required this.smoke,
    required this.sun,
    required this.body,
    required this.trim,
    required this.window,
    required this.flame,
    required this.flameCore,
  });

  factory _LaunchColors.of(ColorScheme scheme) {
    final cloud = scheme.brightness == Brightness.dark
        ? scheme.surfaceContainerHigh
        : scheme.surfaceContainerLowest;
    final sun = Color.lerp(scheme.warning, Colors.white, 0.55)!;
    return _LaunchColors(
      cloud: cloud,
      cloudShade: Color.lerp(cloud, scheme.onSurface, 0.08)!,
      smoke: Color.lerp(cloud, scheme.onSurface, 0.14)!,
      sun: sun,
      body: scheme.onSurface,
      trim: scheme.primary,
      window: scheme.surface,
      flame: Color.lerp(scheme.warning, scheme.error, 0.45)!,
      flameCore: sun,
    );
  }

  final Color cloud;
  final Color cloudShade;
  final Color smoke;
  final Color sun;
  final Color body;
  final Color trim;
  final Color window;
  final Color flame;
  final Color flameCore;
}

/// A fixed scatter in [0, 1): the same picture every time, with no Random.
double _scatter(int index, double seed) => (index * 0.618034 + seed) % 1;

void _paintPad(
  Canvas canvas,
  Offset center,
  double radius,
  _LaunchColors colors, {
  double spread = 0,
}) {
  final fade = 1 - spread;
  if (fade <= 0) {
    return;
  }
  final reach = radius * (1 + 0.6 * spread);
  canvas.drawCircle(
    center,
    reach,
    Paint()..color = colors.trim.withValues(alpha: 0.12 * fade),
  );
  canvas.drawCircle(
    center,
    reach,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = colors.trim.withValues(alpha: 0.5 * fade),
  );
}

void _paintRocket(
  Canvas canvas, {
  required Offset center,
  required double length,
  required double heading,
  required _LaunchColors colors,
  double thrust = 0,
  double flicker = 1,
}) {
  final l = length;
  final w = l * 0.34;
  canvas
    ..save()
    ..translate(center.dx, center.dy)
    ..rotate(heading);
  if (thrust > 0) {
    final flame = l * (0.25 + 0.55 * thrust) * flicker;
    Path plume(double width, double reach) => Path()
      ..moveTo(-w * width, l * 0.37)
      ..quadraticBezierTo(
        -w * width,
        l * 0.37 + reach * 0.55,
        0,
        l * 0.37 + reach,
      )
      ..quadraticBezierTo(
        w * width,
        l * 0.37 + reach * 0.55,
        w * width,
        l * 0.37,
      )
      ..close();
    canvas
      ..drawPath(plume(0.34, flame), Paint()..color = colors.flame)
      ..drawPath(plume(0.18, flame * 0.6), Paint()..color = colors.flameCore);
  }
  final trim = Paint()..color = colors.trim;
  for (final side in const [-1.0, 1.0]) {
    canvas.drawPath(
      Path()
        ..moveTo(side * w * 0.45, l * 0.02)
        ..lineTo(side * w, l * 0.3)
        ..lineTo(side * w, l * 0.42)
        ..lineTo(side * w * 0.42, l * 0.26)
        ..close(),
      trim,
    );
  }
  canvas.drawPath(
    Path()
      ..moveTo(-w * 0.26, l * 0.29)
      ..lineTo(w * 0.26, l * 0.29)
      ..lineTo(w * 0.32, l * 0.37)
      ..lineTo(-w * 0.32, l * 0.37)
      ..close(),
    trim,
  );
  final body = Path()
    ..moveTo(0, -l * 0.5)
    ..cubicTo(w * 0.55, -l * 0.42, w * 0.5, -l * 0.2, w * 0.5, -l * 0.08)
    ..lineTo(w * 0.42, l * 0.3)
    ..lineTo(-w * 0.42, l * 0.3)
    ..lineTo(-w * 0.5, -l * 0.08)
    ..cubicTo(-w * 0.5, -l * 0.2, -w * 0.55, -l * 0.42, 0, -l * 0.5)
    ..close();
  canvas
    ..drawPath(body, Paint()..color = colors.body)
    ..save()
    ..clipPath(body)
    ..drawRect(Rect.fromLTRB(-w, -l * 0.5, w, -l * 0.3), trim)
    ..restore();
  final window = Offset(0, -l * 0.13);
  canvas
    ..drawCircle(window, w * 0.22, Paint()..color = colors.window)
    ..drawCircle(
      window,
      w * 0.22,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = l * 0.035
        ..color = colors.trim,
    )
    ..restore();
}

class _PadPainter extends CustomPainter {
  const _PadPainter({required this.heading, required this.scheme});

  final double heading;
  final ColorScheme scheme;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final colors = _LaunchColors.of(scheme);
    _paintPad(canvas, center, radius, colors);
    _paintRocket(
      canvas,
      center: center,
      length: radius * _rocketToPad,
      heading: heading,
      colors: colors,
    );
  }

  @override
  bool shouldRepaint(_PadPainter oldDelegate) =>
      oldDelegate.heading != heading || oldDelegate.scheme != scheme;
}

class _IconPainter extends CustomPainter {
  const _IconPainter({required this.heading, required this.scheme});

  final double heading;
  final ColorScheme scheme;

  @override
  void paint(Canvas canvas, Size size) {
    _paintRocket(
      canvas,
      center: size.center(Offset.zero),
      length: size.shortestSide * 1.05,
      heading: heading,
      colors: _LaunchColors.of(scheme),
      thrust: 0.3,
    );
  }

  @override
  bool shouldRepaint(_IconPainter oldDelegate) =>
      oldDelegate.heading != heading || oldDelegate.scheme != scheme;
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
    required this.scheme,
  });

  final double progress;
  final Offset rest;
  final Offset course;
  final double padRadius;
  final ColorScheme scheme;

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
    final colors = _LaunchColors.of(scheme);
    final wake = _Wake(size, rest, course, progress);
    final end = _endOf(size);
    _paintBeam(canvas, wake, colors);
    for (final side in const [-1.0, 1.0]) {
      _paintCloudHalf(canvas, wake, colors, side);
    }
    _paintTrail(canvas, wake, colors, end);
    _paintWave(canvas, size, wake, colors);
    if (progress > 0) {
      _paintPad(
        canvas,
        rest,
        padRadius,
        colors,
        spread: _ignite.transform(progress),
      );
      _paintFlyingRocket(canvas, wake, colors, end);
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

  /// Sunlight through the tear, brightest along the wake; the clouds painted
  /// over it keep it inside the gap.
  void _paintBeam(Canvas canvas, _Wake wake, _LaunchColors colors) {
    if (progress <= _beam.begin || progress >= _beam.end) {
      return;
    }
    final glow = 1 - _beam.transform(progress);
    final reach = wake.gapAt(0) + _scallopGap;
    final sun = colors.sun;
    canvas.drawRect(
      Offset.zero & Size.square(wake.halfSpan * 2),
      Paint()
        ..shader = ui.Gradient.linear(
          wake.at(0, -reach),
          wake.at(0, reach),
          [
            sun.withValues(alpha: 0),
            sun.withValues(alpha: 0.75 * glow),
            sun.withValues(alpha: 0),
          ],
          const [0, 0.5, 1],
        ),
    );
  }

  void _paintCloudHalf(
    Canvas canvas,
    _Wake wake,
    _LaunchColors colors,
    double side,
  ) {
    final far = wake.halfSpan * 4;
    final farEnd = wake.at(wake.halfSpan * 2, side * far);
    final farStart = wake.at(-wake.halfSpan * 2, side * far);
    final half = _edgePath(wake, side)
      ..lineTo(farEnd.dx, farEnd.dy)
      ..lineTo(farStart.dx, farStart.dy)
      ..close();
    final cloud = Paint()..color = colors.cloud;
    canvas.drawPath(half, cloud);
    if (wake.parting <= 0) {
      return;
    }
    final shade = Paint();
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
      final radius = _scallopGap * (0.55 + 0.5 * jitter) * (0.7 + 0.6 * open);
      shade.color = colors.cloudShade.withValues(alpha: shown);
      canvas.drawCircle(
        wake.at(s + _scallopGap * 0.5, side * (gap + radius * 1.3)),
        radius * 1.35,
        shade,
      );
      final center = wake.at(s, side * (gap + radius * 0.35));
      rim.color = colors.sun.withValues(alpha: 0.6 * shown);
      canvas
        ..drawCircle(center, radius, rim)
        ..drawCircle(center + wake.across * side * 2.5, radius, cloud);
    }
  }

  void _paintTrail(
    Canvas canvas,
    _Wake wake,
    _LaunchColors colors,
    Offset end,
  ) {
    final launch = _ignite.transform(progress);
    if (launch <= 0) {
      return;
    }
    final flown = _flight.transform(progress);
    final width = _rocketLength * 0.34;
    final restS = wake.distanceOf(rest);
    final pathLength = (end - rest).distance;
    final smoke = Paint();
    final padOpen = wake.openAt(restS);
    smoke.color = colors.smoke.withValues(alpha: 0.9 * (1 - padOpen));
    for (var index = 0; index < _padSmokePuffs; index++) {
      final side = index.isEven ? 1.0 : -1.0;
      final reach = (index ~/ 2 + 1) * width * 0.7 * launch;
      canvas.drawCircle(
        wake.at(restS - width, side * (reach + wake.gapAt(restS))),
        width * (0.6 + 0.5 * launch),
        smoke,
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
          (0.5 + 1.8 * age) *
          perspective *
          (0.8 + 0.4 * _scatter(index, 0.3));
      smoke.color = colors.smoke.withValues(alpha: 0.85 * (1 - open));
      final drift = width * 0.35 * age * _scatter(index, 0.8);
      canvas.drawCircle(
        wake.at(s, side * (drift + wake.gapAt(s) + open * radius)),
        radius,
        smoke,
      );
    }
  }

  void _paintWave(Canvas canvas, Size size, _Wake wake, _LaunchColors colors) {
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
        ..color = colors.sun.withValues(alpha: 0.35 * (1 - wave)),
    );
  }

  void _paintFlyingRocket(
    Canvas canvas,
    _Wake wake,
    _LaunchColors colors,
    Offset end,
  ) {
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
      colors: colors,
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
      oldDelegate.scheme != scheme;
}
