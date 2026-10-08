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
const _revealZoom = 0.06;
const _farScale = 0.55;
const _shake = 1.6;
const _rocketToPad = 1.7;
const _billowReach = 26.0;
const _maxSkyScale = 2.0;

/// Keeps [child] under a painted sky with only a rocket on its pad until
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
  _SkyPrograms? _programs;
  ui.FragmentShader? _cover;
  ui.Image? _sky;
  (Size, double, bool)? _skyKey;

  bool get _open => widget.launched || _peeking;

  @override
  void initState() {
    super.initState();
    _SkyPrograms.load().then((programs) {
      if (!mounted || programs == null) {
        return;
      }
      setState(() {
        _programs = programs;
        _cover = programs.cover.fragmentShader();
      });
    });
  }

  /// Paints the idle sky once per size and theme; every frame after that only
  /// tears and shifts this image.
  ui.Image? _skyFor(Size size, double scale, bool dusk) {
    final key = (size, scale, dusk);
    if (key == _skyKey) {
      return _sky;
    }
    final programs = _programs;
    if (programs == null || size.isEmpty) {
      return null;
    }
    final shader = programs.sky.fragmentShader()
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, dusk ? 1 : 0);
    final recorder = ui.PictureRecorder();
    Canvas(recorder)
      ..scale(scale)
      ..drawRect(Offset.zero & size, Paint()..shader = shader);
    final picture = recorder.endRecording();
    final image = picture.toImageSync(
      (size.width * scale).ceil(),
      (size.height * scale).ceil(),
    );
    picture.dispose();
    shader.dispose();
    _sky?.dispose();
    _skyKey = key;
    return _sky = image;
  }

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
    _cover?.dispose();
    _sky?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dusk = Theme.of(context).brightness == Brightness.dark;
    final scale = math.min(
      MediaQuery.devicePixelRatioOf(context),
      _maxSkyScale,
    );
    final course = _courseOf(Directionality.of(context));
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final sky = _skyFor(size, scale, dusk);
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
                        dusk: dusk,
                        sky: sky,
                        cover: _cover,
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

class _SkyPrograms {
  const _SkyPrograms(this.sky, this.cover);

  static Future<_SkyPrograms?>? _loading;

  static Future<_SkyPrograms?> load() => _loading ??= _load();

  static Future<_SkyPrograms?> _load() async {
    try {
      return _SkyPrograms(
        await ui.FragmentProgram.fromAsset('assets/shaders/launch_sky.frag'),
        await ui.FragmentProgram.fromAsset('assets/shaders/launch_cover.frag'),
      );
    } catch (_) {
      // A renderer without runtime shaders keeps the plain gradient sky.
      return null;
    }
  }

  final ui.FragmentProgram sky;
  final ui.FragmentProgram cover;
}

const _noonSky = [Color(0xFF0B3A9E), Color(0xFF5FB6F2), Color(0xFFD4F1FF)];
const _duskSky = [Color(0xFF141A4E), Color(0xFFB0628F), Color(0xFFFFAA72)];

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
      center: center,
      halfSpan: Offset(size.width, size.height).distance / 2,
      maxGap: farthest + _billowReach * 1.4 + 8,
      parting: _parting.transform(progress),
    );
  }

  const _Wake._({
    required this.center,
    required this.halfSpan,
    required this.maxGap,
    required this.parting,
  });

  final Offset center;
  final double halfSpan;

  /// Enough for either half to clear the screen, billows included.
  final double maxGap;
  final double parting;
}

double _dot(Offset a, Offset b) => a.dx * b.dx + a.dy * b.dy;

class _LaunchPainter extends CustomPainter {
  const _LaunchPainter({
    required this.progress,
    required this.rest,
    required this.course,
    required this.padRadius,
    required this.dusk,
    required this.sky,
    required this.cover,
  });

  final double progress;
  final Offset rest;
  final Offset course;
  final double padRadius;
  final bool dusk;
  final ui.Image? sky;
  final ui.FragmentShader? cover;

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
    final end = _endOf(size);
    final sky = this.sky;
    final cover = this.cover;
    if (sky != null && cover != null) {
      _paintCover(canvas, size, sky, cover, end);
    } else {
      canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = ui.Gradient.linear(
            Offset.zero,
            Offset(0, size.height),
            [
              for (final color in dusk ? _duskSky : _noonSky)
                color.withValues(alpha: 1 - _settle.transform(progress)),
            ],
            const [0, 0.6, 1],
          ),
      );
    }
    if (progress > 0) {
      _paintPad(canvas, rest, padRadius, spread: _ignite.transform(progress));
      _paintFlyingRocket(canvas, end);
    }
  }

  /// Feeds the tear shader in the order `launch_cover.frag` declares its
  /// uniforms.
  void _paintCover(
    Canvas canvas,
    Size size,
    ui.Image sky,
    ui.FragmentShader cover,
    Offset end,
  ) {
    final wake = _Wake(size, rest, course, progress);
    final trailEnd = Offset.lerp(rest, end, _flight.transform(progress))!;
    final beaming = progress > _beam.begin && progress < _beam.end;
    final waving = progress > _wave.begin && progress < _wave.end;
    final wave = _wave.transform(progress);
    final uniforms = [
      size.width,
      size.height,
      dusk ? 1.0 : 0.0,
      wake.center.dx,
      wake.center.dy,
      course.dx,
      course.dy,
      wake.halfSpan,
      wake.maxGap,
      wake.parting,
      rest.dx,
      rest.dy,
      trailEnd.dx,
      trailEnd.dy,
      _rocketLength * 0.3,
      _ignite.transform(progress),
      beaming ? 1 - _beam.transform(progress) : 0.0,
      waving ? wave * size.longestSide * 0.75 : 0.0,
      waving ? 0.6 * (1 - wave) : 0.0,
    ];
    for (final (index, value) in uniforms.indexed) {
      cover.setFloat(index, value);
    }
    cover.setImageSampler(0, sky);
    canvas.drawRect(Offset.zero & size, Paint()..shader = cover);
  }

  void _paintFlyingRocket(Canvas canvas, Offset end) {
    final flown = _flight.transform(progress);
    if (flown >= 1) {
      return;
    }
    final launch = _ignite.transform(progress);
    final settling = (1 - flown * 50).clamp(0.0, 1.0);
    final shake =
        Offset(-course.dy, course.dx) *
        math.sin(progress * 900) *
        _shake *
        launch *
        settling;
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
      oldDelegate.dusk != dusk ||
      oldDelegate.sky != sky ||
      oldDelegate.cover != cover;
}
