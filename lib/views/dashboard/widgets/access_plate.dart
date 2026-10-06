import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _tileHeight = 52.0;
const _glyphSize = 26.0;
const _nodeSize = 5.0;
const _revealDuration = Duration(milliseconds: 700);

/// The dashboard's masthead: the app's mark on an ink tile, a ruled line
/// running off it, and captions naming the app and the profile in use.
class AccessPlate extends ConsumerStatefulWidget {
  const AccessPlate({super.key});

  @override
  ConsumerState<AccessPlate> createState() => _AccessPlateState();
}

class _AccessPlateState extends ConsumerState<AccessPlate>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: _revealDuration,
  );
  late final _tileReveal = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0, 0.55, curve: Curves.easeOutCubic),
  );
  late final _lineReveal = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.3, 1, curve: Curves.easeOutCubic),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) {
      return;
    }
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _tileReveal.dispose();
    _lineReveal.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final profileLabel = ref.watch(
      currentProfileProvider.select((profile) => profile?.realLabel ?? ''),
    );
    final caption = context.textTheme.labelSmall?.toJetBrainsMono.copyWith(
      color: colorScheme.onSurfaceVariant,
      letterSpacing: 2,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          spacing: 12,
          children: [
            ExcludeSemantics(
              child: Text(appName.toUpperCase(), style: caption),
            ),
            Flexible(
              child: Text(
                profileLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: caption?.copyWith(letterSpacing: 0),
              ),
            ),
          ],
        ),
        SizedBox(
          height: _tileHeight,
          child: Row(
            children: [
              FadeTransition(
                opacity: _tileReveal,
                child: DecoratedBox(
                  decoration: ShapeDecoration(
                    color: colorScheme.onSurface,
                    shape: AppShape.xs,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(
                      spacing: 10,
                      children: [
                        CustomPaint(
                          size: const Size.square(_glyphSize),
                          painter: _MarkPainter(color: colorScheme.surface),
                        ),
                        Text(
                          appName.toUpperCase(),
                          style: context.textTheme.titleLarge?.copyWith(
                            color: colorScheme.surface,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: RepaintBoundary(
                  child: CustomPaint(
                    size: Size.infinite,
                    painter: _RuledLinePainter(
                      progress: _lineReveal,
                      lineColor: colorScheme.outline,
                      startColor: colorScheme.onSurface,
                      endColor: colorScheme.primary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The app's own logo, two bars and a dot, as a single color mark.
class _MarkPainter extends CustomPainter {
  _MarkPainter({required this.color});

  static const _viewBox = 240.0;
  static const _strokeWidth = 46.32;

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / _viewBox;
    final stroke = Paint()
      ..color = color
      ..strokeWidth = _strokeWidth * scale
      ..strokeCap = StrokeCap.round;
    Offset at(double x, double y) => Offset(x * scale, y * scale);
    canvas
      ..drawLine(at(59.68, 100.95), at(180.02, 31.47), stroke)
      ..drawLine(at(90.56, 154.43), at(150.74, 119.69), stroke)
      ..drawCircle(
        at(121.44, 207.92),
        _strokeWidth / 2 * scale,
        Paint()..color = color,
      );
  }

  @override
  bool shouldRepaint(_MarkPainter oldDelegate) => oldDelegate.color != color;
}

class _RuledLinePainter extends CustomPainter {
  _RuledLinePainter({
    required this.progress,
    required this.lineColor,
    required this.startColor,
    required this.endColor,
  }) : super(repaint: progress);

  final Animation<double> progress;
  final Color lineColor;
  final Color startColor;
  final Color endColor;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    const start = _nodeSize * 2;
    final end = start + (size.width - start - _nodeSize) * progress.value;
    if (end <= start) {
      return;
    }
    canvas
      ..drawLine(Offset(start, y), Offset(end, y), Paint()..color = lineColor)
      ..drawRect(
        Rect.fromCenter(
          center: Offset(start, y),
          width: _nodeSize,
          height: _nodeSize,
        ),
        Paint()..color = startColor,
      )
      ..drawRect(
        Rect.fromCenter(
          center: Offset(end, y),
          width: _nodeSize,
          height: _nodeSize,
        ),
        Paint()..color = endColor,
      );
  }

  @override
  bool shouldRepaint(_RuledLinePainter oldDelegate) {
    return oldDelegate.lineColor != lineColor ||
        oldDelegate.startColor != startColor ||
        oldDelegate.endColor != endColor;
  }
}
