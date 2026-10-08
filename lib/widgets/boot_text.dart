import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// Where the burst's shock ring ends, as a fraction of the ignition timeline.
const bootBurstEnd = 0.7;

/// How far the ring travels, as a fraction of the longest side.
const bootReach = 0.85;

enum BootPhase { hidden, booting, shown }

/// What [BootText] below it should show; provided by `Ignition`.
class BootScope extends InheritedWidget {
  const BootScope({
    super.key,
    required this.phase,
    required this.progress,
    required this.tick,
    required this.origin,
    required this.rootKey,
    required super.child,
  });

  final BootPhase phase;

  /// How far the ignition has run, 0 to 1.
  final double progress;

  /// Steps at a fixed cadence so scrambled glyphs flicker instead of blurring.
  final int tick;

  /// Where the burst starts, as a fraction of the root's size.
  final Alignment origin;

  /// The box the burst spreads across; a text decodes when the ring reaches it.
  final GlobalKey rootKey;

  static BootScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<BootScope>();
  }

  @override
  bool updateShouldNotify(BootScope oldWidget) {
    return phase != oldWidget.phase ||
        progress != oldWidget.progress ||
        tick != oldWidget.tick ||
        origin != oldWidget.origin;
  }
}

const _pool = '0123456789ABCDEF#%&*+=<>/';
final _readable = RegExp(r'[\p{L}\p{N}]', unicode: true);

/// A [Text] that stays masked as dashes until the surrounding `Ignition`
/// boots, then decodes from noise into [text]. Outside one it is a plain Text.
class BootText extends StatelessWidget {
  const BootText(
    this.text, {
    super.key,
    this.style,
    this.maxLines,
    this.overflow,
    this.textAlign,
  });

  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;

  static const _decodeSpan = 1 - bootBurstEnd;

  static String mask(String text) => text.replaceAll(_readable, '-');

  static String decode(String text, double decoded, int tick) {
    final units = text.runes.toList();
    final resolved = (decoded * units.length).floor();
    final buffer = StringBuffer();
    for (final (index, unit) in units.indexed) {
      final char = String.fromCharCode(unit);
      if (index < resolved || !_readable.hasMatch(char)) {
        buffer.write(char);
        continue;
      }
      final pick = (tick * 31 + index * 17 + unit) % _pool.length;
      buffer.write(_pool[pick]);
    }
    return buffer.toString();
  }

  /// When the shock ring reaches this text, as a fraction of the timeline.
  double _arrival(BuildContext context, BootScope scope) {
    final root = scope.rootKey.currentContext?.findRenderObject();
    final self = context.findRenderObject();
    if (root is! RenderBox ||
        self is! RenderBox ||
        !root.hasSize ||
        !self.hasSize ||
        !self.attached) {
      return 0;
    }
    final center = root.globalToLocal(
      self.localToGlobal(self.size.center(Offset.zero)),
    );
    final reach = root.size.longestSide * bootReach;
    final distance = (center - scope.origin.alongSize(root.size)).distance;
    final spread = (distance / reach).clamp(0.0, 1.0);
    // The ring's radius follows easeOutCubic, so invert it for the time.
    return bootBurstEnd * (1 - math.pow(1 - spread, 1 / 3));
  }

  String _shown(BuildContext context, BootScope? scope) {
    if (scope == null) {
      return text;
    }
    return switch (scope.phase) {
      BootPhase.shown => text,
      BootPhase.hidden => mask(text),
      BootPhase.booting => _booting(context, scope),
    };
  }

  String _booting(BuildContext context, BootScope scope) {
    final start = _arrival(context, scope);
    if (scope.progress < start) {
      return mask(text);
    }
    final decoded = ((scope.progress - start) / _decodeSpan).clamp(0.0, 1.0);
    return decode(text, decoded, scope.tick);
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _shown(context, BootScope.maybeOf(context)),
      style: style,
      maxLines: maxLines,
      overflow: overflow,
      textAlign: textAlign,
    );
  }
}
