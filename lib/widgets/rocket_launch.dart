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

/// The sky the rocket waits in, kept whatever the app's colors: a summer noon,
/// or magic hour when the app is dark.
class _Sky {
  const _Sky({
    required this.gradient,
    required this.shadeTop,
    required this.shadeBottom,
    required this.body,
    required this.light,
    required this.rim,
    required this.sun,
  });

  static const noon = _Sky(
    gradient: [
      Color(0xFF0B3A9E),
      Color(0xFF1E6FD9),
      Color(0xFF5FB6F2),
      Color(0xFFD4F1FF),
    ],
    shadeTop: Color(0xFFC3CFEA),
    shadeBottom: Color(0xFF7A90C4),
    body: Color(0xFFEEF3FC),
    light: Color(0xFFFFFFFF),
    rim: Color(0xFFFFE7B8),
    sun: Color(0xFFFFFBEA),
  );

  static const twilight = _Sky(
    gradient: [
      Color(0xFF141A4E),
      Color(0xFF3B3C8F),
      Color(0xFFB0628F),
      Color(0xFFFFAA72),
    ],
    shadeTop: Color(0xFF8E79B8),
    shadeBottom: Color(0xFF4E4583),
    body: Color(0xFFF7C6B4),
    light: Color(0xFFFFE9D2),
    rim: Color(0xFFFFB070),
    sun: Color(0xFFFFE2B8),
  );

  static _Sky of(Brightness brightness) =>
      brightness == Brightness.dark ? twilight : noon;

  final List<Color> gradient;
  final Color shadeTop;
  final Color shadeBottom;
  final Color body;
  final Color light;
  final Color rim;
  final Color sun;
}

const _white = Color(0xFFFFFFFF);
const _line = Color(0x731E2846);

// Warm key light on the lit side (+x), cool sky bounce in the shadow.
const _hull = [
  Color(0xFF7E8FB0),
  Color(0xFFB9C7DE),
  Color(0xFFEEF3FA),
  Color(0xFFFFFFFF),
  Color(0xFFFFF1D6),
];
const _livery = [
  Color(0xFF6E1820),
  Color(0xFFB52A33),
  Color(0xFFE5474A),
  Color(0xFFFF7F6A),
  Color(0xFFFFB48C),
];
const _finLit = [Color(0xFFC9333B), Color(0xFFF06A5A), Color(0xFFFFAA82)];
const _finShade = [Color(0xFF4E2A55), Color(0xFF7A2231), Color(0xFF9E2A35)];
const _keel = [
  Color(0xFF4E2A55),
  Color(0xFF7A2231),
  Color(0xFF9E2A35),
  Color(0xFFF06A5A),
  Color(0xFFFFAA82),
];
const _metal = [
  Color(0xFF3F4A63),
  Color(0xFF8E9CB8),
  Color(0xFFD9E1EE),
  Color(0xFF9AA8C2),
];
const _glass = [Color(0xFF9FD6FF), Color(0xFF2F74D0), Color(0xFF13306E)];

/// Where the sun sits, as a fraction of the screen; its light falls from the
/// upper right.
const _sunAt = Offset(0.86, 0.07);
const _light = Offset(0.62, -0.78);

/// A fixed scatter in [0, 1): the same picture every time, with no Random.
double _scatter(int index, double seed) => (index * 0.618034 + seed) % 1;

/// A repeatable hash in [0, 1) that, unlike [_scatter], does not correlate
/// across seeds.
double _hash(int index, double seed) {
  final value = math.sin(index * 127.1 + seed * 311.7) * 43758.5453;
  return value - value.floorToDouble();
}

/// Cumulus grown from an anchor: puffs piled upward, broad at the base and
/// narrowing into a cauliflower head.
Iterable<(double, double, double)> _grow(
  double seed,
  double x,
  double y,
  double width,
  double height,
  int count,
) sync* {
  for (var index = 0; index < count; index++) {
    final up = math.pow(_hash(index, seed), 1.4).toDouble();
    final side = _hash(index, seed + 1) - 0.5;
    yield (
      x + side * width * (1 - up * 0.6),
      y - up * height,
      width * (0.12 + 0.1 * _hash(index, seed + 2)) * (1 - up * 0.35),
    );
  }
}

/// The idle sky's clouds as puffs: where, as fractions of the screen, and how
/// big, as a fraction of its width. A cumulonimbus towers on the start side.
final _skyPuffs = [
  ..._grow(1, 0.2, 0.97, 0.7, 0.48, 46),
  ..._grow(2, 0.62, 1.02, 1.1, 0.1, 26),
  ..._grow(3, 0.97, 1, 0.45, 0.22, 16),
  ..._grow(4, 0.7, 0.42, 0.3, 0.05, 11),
  ..._grow(5, 0.3, 0.25, 0.22, 0.03, 8),
];

/// Cirrus streaks high up: where, how long, and how thin.
const _wisps = [
  (0.3, 0.12, 0.34, 0.012),
  (0.62, 0.17, 0.26, 0.009),
  (0.2, 0.3, 0.2, 0.008),
];

/// Lens ghosts strung from the sun toward the middle: how far along, how big,
/// what tint and how strong.
const _flares = [
  (0.35, 0.035, Color(0xFFAAE6FF), 0.22),
  (0.55, 0.06, Color(0xFFBEFFD2), 0.12),
  (0.8, 0.02, Color(0xFFFFC8F0), 0.25),
  (1.15, 0.09, Color(0xFFA0C8FF), 0.1),
  (1.4, 0.04, Color(0xFFFFF0BE), 0.18),
];

final _motes = [
  for (var index = 0; index < 14; index++)
    (
      _scatter(index, 0.12),
      0.05 + _scatter(index, 0.66) * 0.6,
      1 + _scatter(index, 0.4) * 2.4,
    ),
];

typedef _Puff = ({Offset center, double radius, double alpha});

Paint _radial(
  Offset center,
  double radius,
  List<Color> colors,
  List<double> stops,
) => Paint()..shader = ui.Gradient.radial(center, radius, colors, stops);

/// A horizontal gradient spread evenly over [colors], for shading a round
/// part lit from one side.
Paint _across(double from, double to, List<Color> colors) => Paint()
  ..shader = ui.Gradient.linear(Offset(from, 0), Offset(to, 0), colors, [
    for (var index = 0; index < colors.length; index++)
      index / (colors.length - 1),
  ]);

/// A painted cloud: a crisp silhouette in the shaded base tone, darker toward
/// the ground, with soft sunlight laid inside it puff by puff.
void _paintCloudMass(
  Canvas canvas,
  List<_Puff> puffs,
  _Sky sky,
  double height,
) {
  final base = Paint()
    ..shader = ui.Gradient.linear(Offset.zero, Offset(0, height), [
      sky.shadeTop,
      sky.shadeBottom,
    ]);
  final visible = [
    for (final puff in puffs)
      if (puff.alpha > 0 && puff.radius > 0) puff,
  ];
  for (final puff in visible) {
    canvas.drawCircle(
      puff.center,
      puff.radius,
      base..color = base.color.withValues(alpha: puff.alpha),
    );
  }
  for (final puff in visible) {
    final center = puff.center + _light * (puff.radius * 0.28);
    final radius = puff.radius * 0.98;
    canvas.drawCircle(
      center,
      radius,
      _radial(
        center,
        radius,
        [
          sky.body.withValues(alpha: puff.alpha),
          sky.body.withValues(alpha: 0.9 * puff.alpha),
          sky.body.withValues(alpha: 0),
        ],
        const [0, 0.55, 1],
      ),
    );
  }
  for (final puff in visible) {
    final center = puff.center + _light * (puff.radius * 0.48);
    final radius = puff.radius * 0.6;
    canvas.drawCircle(
      center,
      radius,
      _radial(
        center,
        radius,
        [
          sky.light.withValues(alpha: 0.95 * puff.alpha),
          sky.light.withValues(alpha: 0),
        ],
        const [0, 1],
      ),
    );
  }
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
      reach * 1.2,
      _radial(
        center,
        reach * 1.2,
        [
          _white.withValues(alpha: 0),
          _white.withValues(alpha: 0.12 * fade),
          _white.withValues(alpha: 0.45 * fade),
          _white.withValues(alpha: 0),
        ],
        const [0, 0.55, 0.82, 1],
      ),
    )
    ..drawCircle(
      center,
      reach - 1.5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = _white.withValues(alpha: 0.85 * fade),
    );
}

void _paintFlame(
  Canvas canvas,
  double l,
  double hw,
  double thrust,
  double flicker,
) {
  final nozzle = Offset(0, l * 0.34);
  final reach = l * (0.45 + 0.85 * thrust) * flicker;
  final bloom = l * 0.9 * thrust;
  canvas.drawCircle(
    nozzle,
    bloom,
    _radial(
      nozzle,
      bloom,
      const [
        Color(0xE6FFFAE6),
        Color(0x8CFFD68C),
        Color(0x2EFF9650),
        Color(0x00FF783C),
      ],
      const [0, 0.18, 0.5, 1],
    ),
  );
  void plume(
    double width,
    double length,
    List<Color> colors,
    List<double> stops,
  ) {
    final w = hw * width;
    final y = nozzle.dy;
    canvas.drawPath(
      Path()
        ..moveTo(-w, y)
        ..cubicTo(
          -w * 1.3,
          y + length * 0.35,
          -w * 0.45,
          y + length * 0.8,
          0,
          y + length,
        )
        ..cubicTo(w * 0.45, y + length * 0.8, w * 1.3, y + length * 0.35, w, y)
        ..close(),
      Paint()
        ..shader = ui.Gradient.linear(
          nozzle,
          nozzle + Offset(0, length),
          colors,
          stops,
        ),
    );
  }

  plume(
    1,
    reach,
    const [Color(0xF2FFBE64), Color(0xB3FF783C), Color(0x00FF5A3C)],
    const [0, 0.4, 1],
  );
  plume(
    0.62,
    reach * 0.66,
    const [Color(0xFFFFF8D2), Color(0xD9FFD678), Color(0x00FFBE5A)],
    const [0, 0.6, 1],
  );
  plume(
    0.3,
    reach * 0.4,
    const [Color(0xFFFFFFFF), Color(0x00FFFFFF)],
    const [0, 1],
  );
}

/// A painted white rocket with a red livery, drawn nose-up around its middle
/// and turned to [heading]. Its lit side is +x, which faces the sun once it
/// points up and toward the start side.
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
  final line = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = l * 0.012
    ..strokeJoin = StrokeJoin.round
    ..color = _line;
  void part(Path path, Paint fill) => canvas
    ..drawPath(path, fill)
    ..drawPath(path, line);

  canvas
    ..save()
    ..translate(center.dx, center.dy)
    ..rotate(heading);
  if (thrust > 0) {
    _paintFlame(canvas, l, hw, thrust, flicker);
  }
  for (final side in const [-1.0, 1.0]) {
    part(
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
        side > 0 ? _finLit : _finShade,
      ),
    );
  }
  part(
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
      Rect.fromLTWH(-hw, -l * 0.5, hw * 2, l),
      Paint()
        ..shader = ui.Gradient.linear(Offset(0, -l * 0.5), Offset(0, base), [
          _white.withValues(alpha: 0),
          const Color(0x38283C5A),
        ]),
    )
    ..drawRect(
      Rect.fromLTWH(hw * 0.5, -l * 0.27, hw * 0.12, l * 0.36),
      Paint()..color = _white.withValues(alpha: 0.85),
    )
    ..restore()
    ..drawPath(body, line);
  part(
    Path()
      ..moveTo(-hw * 0.17, l * 0.1)
      ..lineTo(hw * 0.17, l * 0.1)
      ..lineTo(hw * 0.17, l * 0.38)
      ..quadraticBezierTo(0, l * 0.43, -hw * 0.17, l * 0.38)
      ..close(),
    _across(-hw * 0.17, hw * 0.17, _keel),
  );
  final window = Offset(0, -l * 0.1);
  final outer = hw * 0.58;
  final inner = hw * 0.44;
  final glass = Path()..addOval(Rect.fromCircle(center: window, radius: inner));
  canvas
    ..drawCircle(window, outer, _across(-outer, outer, _metal))
    ..drawPath(
      glass,
      Paint()
        ..shader = ui.Gradient.linear(
          window - Offset(0, inner),
          window + Offset(0, inner),
          _glass,
          const [0, 0.45, 1],
        ),
    )
    ..save()
    ..clipPath(glass)
    ..translate(window.dx + inner * 0.25, window.dy - inner * 0.35)
    ..rotate(-0.5)
    ..drawOval(
      Rect.fromCenter(
        center: Offset.zero,
        width: inner * 1.1,
        height: inner * 0.44,
      ),
      Paint()..color = _white.withValues(alpha: 0.75),
    )
    ..restore()
    ..drawPath(glass, line);
  final glint = Offset(hw * 0.62, -l * 0.33);
  canvas
    ..drawCircle(
      glint,
      hw * 0.5,
      _radial(
        glint,
        hw * 0.5,
        [_white.withValues(alpha: 0.95), _white.withValues(alpha: 0)],
        const [0, 1],
      ),
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
    _paintTrail(canvas, size, wake, end);
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
    final reach = wake.gapAt(0) + _scallopGap * 2;
    canvas.drawRect(
      Offset.zero & Size.square(wake.halfSpan * 2),
      Paint()
        ..shader = ui.Gradient.linear(
          wake.at(0, -reach),
          wake.at(0, reach),
          [
            sky.rim.withValues(alpha: 0),
            sky.rim.withValues(alpha: 0.5 * glow),
            sky.sun.withValues(alpha: 0.95 * glow),
            sky.rim.withValues(alpha: 0.5 * glow),
            sky.rim.withValues(alpha: 0),
          ],
          const [0, 0.35, 0.5, 0.65, 1],
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
      rim.color = sky.rim.withValues(alpha: 0.95 * shown);
      canvas.drawCircle(center - wake.across * side * 3, radius * 1.04, rim);
      billows.add((center: center, radius: radius, alpha: shown));
    }
    _paintCloudMass(canvas, billows, sky, size.height);
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
          sky.gradient,
          const [0, 0.38, 0.72, 1],
        ),
    );
    final sun = moved(Offset(_sunAt.dx * w, _sunAt.dy * h));
    final ray = Paint()..color = sky.sun.withValues(alpha: 0.06);
    for (var index = 0; index < 6; index++) {
      final angle = math.pi * 0.62 + index * 0.13 + _scatter(index, 0.3) * 0.06;
      final spread = 0.03 + 0.025 * _scatter(index, 0.7);
      final from = sun + Offset.fromDirection(angle - spread, h * 1.5);
      final to = sun + Offset.fromDirection(angle + spread, h * 1.5);
      canvas.drawPath(
        Path()
          ..moveTo(sun.dx, sun.dy)
          ..lineTo(from.dx, from.dy)
          ..lineTo(to.dx, to.dy)
          ..close(),
        ray,
      );
    }
    for (final (x, y, length, thin) in _wisps) {
      final center = moved(Offset(x * w, y * h));
      final reach = length * w;
      canvas
        ..save()
        ..translate(center.dx, center.dy)
        ..rotate(-0.12)
        ..scale(1, thin * 6)
        ..drawCircle(
          Offset.zero,
          reach,
          _radial(
            Offset.zero,
            reach,
            [sky.light.withValues(alpha: 0.55), sky.light.withValues(alpha: 0)],
            const [0, 1],
          ),
        )
        ..restore();
    }
    _paintContrail(
      canvas,
      moved(Offset(-0.05 * w, 0.34 * h)),
      moved(Offset(0.58 * w, 0.16 * h)),
    );
    _paintCloudMass(
      canvas,
      [
        for (final (x, y, radius) in _skyPuffs)
          (center: moved(Offset(x * w, y * h)), radius: radius * w, alpha: 1.0),
      ],
      sky,
      h,
    );
    _paintSun(canvas, size, sun);
    for (final (x, y, radius) in _motes) {
      final center = moved(Offset(x * w, y * h));
      canvas.drawCircle(
        center,
        radius * 2.4,
        _radial(
          center,
          radius * 2.4,
          const [Color(0xCCFFFFF0), Color(0x00FFFFF0)],
          const [0, 1],
        ),
      );
    }
  }

  /// A high airliner's contrail, fading out behind it.
  void _paintContrail(Canvas canvas, Offset from, Offset to) {
    Paint stroke(double width, double alpha) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = width
      ..shader = ui.Gradient.linear(from, to, [
        _white.withValues(alpha: 0),
        _white.withValues(alpha: alpha),
      ]);
    canvas
      ..drawLine(from, to, stroke(7, 0.21))
      ..drawLine(from, to, stroke(2, 0.85))
      ..drawCircle(to, 2.2, Paint()..color = _white.withValues(alpha: 0.95));
  }

  void _paintSun(Canvas canvas, Size size, Offset sun) {
    final w = size.width;
    canvas.drawRect(
      Offset.zero & size,
      _radial(
        sun,
        w * 0.95,
        [
          sky.sun,
          sky.sun,
          sky.sun.withValues(alpha: 0.75),
          sky.sun.withValues(alpha: 0.28),
          sky.sun.withValues(alpha: 0.08),
          sky.sun.withValues(alpha: 0),
        ],
        const [0, 0.05, 0.1, 0.3, 0.6, 1],
      ),
    );
    canvas
      ..save()
      ..translate(sun.dx, sun.dy)
      ..scale(1, 0.025)
      ..drawCircle(
        Offset.zero,
        w * 0.7,
        _radial(
          Offset.zero,
          w * 0.7,
          [_white.withValues(alpha: 0.7), _white.withValues(alpha: 0)],
          const [0, 1],
        ),
      )
      ..restore();
    final aim = Offset(w * 0.42, size.height * 0.5);
    for (final (along, radius, tint, alpha) in _flares) {
      final center = sun + (aim - sun) * along;
      final reach = w * radius;
      final ghost = Path();
      for (var corner = 0; corner < 6; corner++) {
        final point =
            center + Offset.fromDirection(corner * math.pi / 3 + 0.3, reach);
        corner == 0
            ? ghost.moveTo(point.dx, point.dy)
            : ghost.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(
        ghost..close(),
        Paint()..color = tint.withValues(alpha: alpha),
      );
    }
  }

  void _paintTrail(Canvas canvas, Size size, _Wake wake, Offset end) {
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
    _paintCloudMass(canvas, smoke, sky, size.height);
  }

  /// The air blast: a soft bright band racing out from the middle.
  void _paintWave(Canvas canvas, Size size, _Wake wake) {
    if (progress <= _wave.begin || progress >= _wave.end) {
      return;
    }
    final wave = _wave.transform(progress);
    final reach = wave * size.longestSide * 0.75;
    final band = 10 + 40 * (1 - wave);
    final outer = reach + band * 0.3;
    final start = math.max(0.0, reach - band) / outer;
    canvas.drawCircle(
      wake.center,
      outer,
      _radial(
        wake.center,
        outer,
        [
          _white.withValues(alpha: 0),
          _white.withValues(alpha: 0),
          _white.withValues(alpha: 0.45 * (1 - wave)),
          _white.withValues(alpha: 0),
        ],
        [0, start, start + 0.75 * (1 - start), 1],
      ),
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
