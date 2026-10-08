import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'navigation_dock.dart';

const _launchDuration = Duration(milliseconds: 2200);
const _landDuration = Duration(milliseconds: 900);
const _ignite = Interval(0, 0.14, curve: Curves.easeOut);
const _flight = Interval(0.08, 0.6, curve: Curves.easeInCubic);
const _parting = Interval(0.5, 1);
const _beam = Interval(0.5, 0.86, curve: Curves.easeOut);
const _settle = Interval(0.5, 1, curve: Curves.easeOutCubic);
const _revealZoom = 0.025;
const _farScale = 0.38;
const _shake = 0.35;
const _rocketToPad = 1.95;
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
  (Size, double, bool, TextDirection)? _skyKey;
  final _artwork = <bool, ui.Image>{};
  final _requestedArtwork = <bool>{};

  bool get _open => widget.launched || _peeking;

  @override
  void initState() {
    super.initState();
    _SkyPrograms.load().then((programs) {
      if (!mounted || programs == null) {
        return;
      }
      setState(() {
        _skyKey = null;
        _programs = programs;
        _cover = programs.cover.fragmentShader();
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_controller.isCompleted) {
      unawaited(_loadArtwork(Theme.of(context).brightness == Brightness.dark));
    }
  }

  Future<void> _loadArtwork(bool dusk) async {
    if (!_requestedArtwork.add(dusk)) {
      return;
    }
    ui.Codec? codec;
    try {
      final data = await rootBundle.load(
        'assets/images/launch_${dusk ? 'dusk' : 'noon'}.png',
      );
      codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
      final frame = await codec.getNextFrame();
      if (!mounted) {
        frame.image.dispose();
        return;
      }
      setState(() {
        _artwork[dusk] = frame.image;
        _skyKey = null;
      });
    } catch (_) {
      // Keep the shader sky when artwork cannot be decoded by the renderer.
    } finally {
      codec?.dispose();
    }
  }

  ui.Image? _skyFor(
    Size size,
    double scale,
    bool dusk,
    TextDirection direction,
  ) {
    final key = (size, scale, dusk, direction);
    if (key == _skyKey) {
      return _sky;
    }
    final artwork = _artwork[dusk];
    final programs = _programs;
    if (size.isEmpty || (artwork == null && programs == null)) {
      return null;
    }
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(scale);
    ui.FragmentShader? shader;
    if (artwork != null) {
      paintImage(
        canvas: canvas,
        rect: Offset.zero & size,
        image: artwork,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.medium,
        flipHorizontally: direction == TextDirection.rtl,
      );
    } else {
      shader = programs!.sky.fragmentShader()
        ..setFloat(0, size.width)
        ..setFloat(1, size.height)
        ..setFloat(2, dusk ? 1 : 0);
      canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
    }
    final picture = recorder.endRecording();
    final image = picture.toImageSync(
      (size.width * scale).ceil(),
      (size.height * scale).ceil(),
    );
    picture.dispose();
    shader?.dispose();
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
    if (!_open) {
      unawaited(_loadArtwork(Theme.of(context).brightness == Brightness.dark));
    }
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
    for (final image in _artwork.values) {
      image.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dusk = Theme.of(context).brightness == Brightness.dark;
    final scale = math.min(
      MediaQuery.devicePixelRatioOf(context),
      _maxSkyScale,
    );
    final direction = Directionality.of(context);
    final course = _courseOf(direction);
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final sky = _controller.isCompleted
            ? null
            : _skyFor(size, scale, dusk, direction);
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
const _ink = Color(0xA33B5078);
const _shadow = Color(0xFF9EBADE);
const _deepBlue = Color(0xFF354F80);
const _blue = Color(0xFF628DC5);
const _rim = Color(0xFFFFE8C5);
const _accent = Color(0xFFEDA889);

Paint _radial(
  Offset center,
  double radius,
  List<Color> colors,
  List<double> stops,
) => Paint()..shader = ui.Gradient.radial(center, radius, colors, stops);

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
  final reach = radius * (1 + 0.45 * spread);
  canvas
    ..drawCircle(
      center,
      reach * 1.3,
      _radial(
        center,
        reach * 1.3,
        [
          const Color(0xFF9BCDF5).withValues(alpha: 0.2 * fade),
          _white.withValues(alpha: 0),
        ],
        const [0, 1],
      ),
    )
    ..drawCircle(
      center,
      reach,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = _white.withValues(alpha: 0.65 * fade),
    );
}

void _paintFlame(
  Canvas canvas,
  double length,
  double halfWidth,
  double thrust,
  double flicker,
) {
  final nozzle = Offset(0, length * 0.38);
  final reach = length * (0.25 + thrust) * flicker;
  final radius = length * 0.42 * thrust;
  canvas.drawCircle(
    nozzle,
    radius,
    _radial(
      nozzle,
      radius,
      const [Color(0xB3E8F9FF), Color(0x3382C8FF), Color(0x0082C8FF)],
      const [0, 0.3, 1],
    ),
  );
  final plume = Path()
    ..moveTo(-halfWidth * 0.65, nozzle.dy)
    ..quadraticBezierTo(
      -halfWidth * 0.9,
      nozzle.dy + reach * 0.3,
      0,
      nozzle.dy + reach,
    )
    ..quadraticBezierTo(
      halfWidth * 0.9,
      nozzle.dy + reach * 0.3,
      halfWidth * 0.65,
      nozzle.dy,
    )
    ..close();
  canvas.drawPath(
    plume,
    Paint()
      ..shader = ui.Gradient.linear(
        nozzle,
        nozzle + Offset(0, reach),
        const [
          Color(0xFFFFF6E2),
          Color(0xFFE9F9FF),
          Color(0x667DC8FF),
          Color(0x007DC8FF),
        ],
        const [0, 0.2, 0.6, 1],
      ),
  );
}

void _paintRocket(
  Canvas canvas, {
  required Offset center,
  required double length,
  required double heading,
  double thrust = 0,
  double flicker = 1,
}) {
  final l = length;
  final hw = l * 0.09;
  final outline = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = l * 0.008
    ..strokeJoin = StrokeJoin.round
    ..color = _ink;
  canvas
    ..save()
    ..translate(center.dx, center.dy)
    ..rotate(heading);
  if (thrust > 0) {
    _paintFlame(canvas, l, hw, thrust, flicker);
  }
  for (final side in const [-1.0, 1.0]) {
    final fin = Path()
      ..moveTo(side * hw * 0.8, l * 0.05)
      ..lineTo(side * hw * 2.0, l * 0.34)
      ..lineTo(side * hw * 1.85, l * 0.4)
      ..lineTo(side * hw * 0.7, l * 0.28)
      ..close();
    canvas
      ..drawPath(fin, Paint()..color = side < 0 ? _deepBlue : _blue)
      ..drawPath(fin, outline);
  }
  final nozzle = Path()
    ..moveTo(-hw * 0.55, l * 0.3)
    ..lineTo(hw * 0.55, l * 0.3)
    ..lineTo(hw * 0.7, l * 0.38)
    ..lineTo(-hw * 0.7, l * 0.38)
    ..close();
  canvas.drawPath(nozzle, Paint()..color = _deepBlue);
  final hull = Path()
    ..moveTo(0, -l * 0.56)
    ..cubicTo(hw * 0.25, -l * 0.49, hw, -l * 0.3, hw, -l * 0.16)
    ..lineTo(hw * 0.85, l * 0.31)
    ..quadraticBezierTo(0, l * 0.35, -hw * 0.85, l * 0.31)
    ..lineTo(-hw, -l * 0.16)
    ..cubicTo(-hw, -l * 0.3, -hw * 0.25, -l * 0.49, 0, -l * 0.56)
    ..close();
  canvas
    ..drawPath(hull, Paint()..color = const Color(0xFFF5F8FF))
    ..save()
    ..clipPath(hull)
    ..drawPath(
      Path()
        ..moveTo(0, -l * 0.56)
        ..quadraticBezierTo(-hw * 0.4, -l * 0.1, -hw * 0.25, l * 0.32)
        ..lineTo(-hw * 1.1, l * 0.36)
        ..lineTo(-hw * 1.1, -l * 0.56)
        ..close(),
      Paint()..color = _shadow,
    )
    ..drawPath(
      Path()
        ..moveTo(hw * 0.35, -l * 0.4)
        ..quadraticBezierTo(hw * 0.9, -l * 0.15, hw * 0.5, l * 0.31)
        ..lineTo(hw * 1.1, l * 0.31)
        ..lineTo(hw * 1.1, -l * 0.4)
        ..close(),
      Paint()..color = _rim,
    )
    ..drawRect(
      Rect.fromLTWH(-hw, l * 0.18, hw * 2, l * 0.035),
      Paint()..color = _accent,
    )
    ..drawRect(
      Rect.fromLTWH(-hw, l * 0.25, hw * 2, l * 0.05),
      Paint()..color = _blue,
    )
    ..restore()
    ..drawPath(hull, outline);
  final glass = Path()
    ..moveTo(0, -l * 0.29)
    ..quadraticBezierTo(hw * 0.5, -l * 0.19, hw * 0.45, -l * 0.11)
    ..lineTo(-hw * 0.45, -l * 0.11)
    ..quadraticBezierTo(-hw * 0.5, -l * 0.19, 0, -l * 0.29)
    ..close();
  canvas
    ..drawPath(glass, Paint()..color = _deepBlue)
    ..drawLine(
      Offset(hw * 0.14, -l * 0.23),
      Offset(hw * 0.3, -l * 0.14),
      Paint()
        ..strokeWidth = l * 0.012
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFFBDEBFF),
    )
    ..drawLine(Offset(-hw * 0.6, l * 0.05), Offset(hw * 0.6, l * 0.05), outline)
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
    } else if (sky != null) {
      canvas.drawImageRect(
        sky,
        Rect.fromLTWH(0, 0, sky.width.toDouble(), sky.height.toDouble()),
        Offset.zero & size,
        Paint()
          ..color = _white.withValues(alpha: 1 - _settle.transform(progress)),
      );
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
      _rocketLength * 0.07,
      _ignite.transform(progress),
      beaming ? 1 - _beam.transform(progress) : 0.0,
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
        math.sin(progress * 160) *
        _shake *
        launch *
        settling;
    _paintRocket(
      canvas,
      center: Offset.lerp(rest, end, flown)! + shake,
      length: _rocketLength * (1 - (1 - _farScale) * flown),
      heading: _headingOf(course),
      thrust: launch,
      flicker: 0.97 + 0.03 * math.sin(progress * 90),
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
