import 'package:fl_clash/views/dashboard/route_flow.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

class _CountPaint extends CustomPainter {
  _CountPaint(this.onPaint);
  final VoidCallback onPaint;

  @override
  void paint(Canvas canvas, Size size) {
    onPaint();
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF222222),
    );
  }

  @override
  bool shouldRepaint(_CountPaint oldDelegate) => false;
}

void main() {
  for (final vertical in [false, true]) {
    testWidgets(
      'flow repaints without rebuilding or repainting nodes, vertical=$vertical',
      (tester) async {
        var builds = 0;
        var paints = 0;
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(),
            child: NetworkRouteFlow(
              routes: const [
                (Color(0xFF3563E9), true),
                (Color(0xFF12AE80), true),
                (Color(0xFF0F9FB0), true),
                (Color(0xFFE0632F), true),
                (Color(0xFF8B5CF6), true),
                (Color(0xFFD55181), true),
              ],
              animate: true,
              vertical: vertical,
              child: Builder(
                builder: (_) {
                  builds++;
                  return SizedBox(
                    width: 400,
                    height: 156,
                    child: CustomPaint(painter: _CountPaint(() => paints++)),
                  );
                },
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 16));
        final flowPaint = tester
            .widget<CustomPaint>(find.byType(CustomPaint).first)
            .painter!;
        var ticks = 0;
        void tick() => ticks++;
        flowPaint.addListener(tick);
        final baselineBuilds = builds;
        final baselinePaints = paints;
        for (var i = 0; i < 12; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        expect(ticks, 12);
        expect(builds - baselineBuilds, 0);
        expect(paints - baselinePaints, 0);
        flowPaint.removeListener(tick);
        await tester.pumpWidget(const SizedBox.shrink());
        expect(tester.binding.transientCallbackCount, 0);
      },
    );
  }

  for (final reason in [
    'paused',
    'reduced motion',
    'offstage',
    'no successful routes',
  ]) {
    testWidgets('flow stops scheduling frames for $reason and can resume', (
      tester,
    ) async {
      Future<void> show(bool stopped) => tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(
            disableAnimations: stopped && reason == 'reduced motion',
          ),
          child: TickerMode(
            enabled: !(stopped && reason == 'offstage'),
            child: NetworkRouteFlow(
              routes: [
                (
                  const Color(0xFF3563E9),
                  !(stopped && reason == 'no successful routes'),
                ),
              ],
              animate: !(stopped && reason == 'paused'),
              child: const SizedBox(width: 400, height: 156),
            ),
          ),
        ),
      );
      await show(false);
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.binding.transientCallbackCount, 1);
      await show(true);
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.binding.transientCallbackCount, 0);
      await show(false);
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.binding.transientCallbackCount, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
