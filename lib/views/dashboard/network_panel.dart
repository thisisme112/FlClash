import 'package:fl_clash/ui/ui.dart';
import 'package:flutter/widgets.dart';

class NetworkPanel extends StatelessWidget {
  const NetworkPanel({super.key, required this.child, this.accent});

  final Widget child;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: ShapeDecoration(
        color: SurfaceLevel.card.colorOf(scheme),
        shape: AppShape.sm.copyWith(
          side: BorderSide(color: accent ?? scheme.outlineVariant),
        ),
        shadows: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: scheme.brightness == Brightness.dark ? 0.2 : 0.04,
            ),
            offset: const Offset(0, 1),
            blurRadius: 3,
          ),
        ],
      ),
      child: child,
    );
  }
}
