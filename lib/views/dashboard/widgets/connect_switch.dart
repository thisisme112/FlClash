import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/icons/icons.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _height = 72.0;
const _knobInset = 5.0;
const _knobSize = _height - _knobInset * 2;
const _labelGap = 8.0;
const _iconMorphDuration = Duration(milliseconds: 450);

class ConnectSwitch extends ConsumerWidget {
  const ConnectSwitch({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isStart = ref.watch(isStartProvider);
    final suspend = ref.watch(suspendProvider);
    final appLocalizations = context.appLocalizations;
    final colorScheme = context.colorScheme;
    final running = isStart && !suspend;
    final duration = context.motionDuration(commonDuration);
    final foreground = running
        ? colorScheme.onPrimaryContainer
        : colorScheme.onSurface;
    final fill = running ? colorScheme.primaryContainer : colorScheme.surface;
    final label = switch ((isStart, suspend)) {
      (false, _) => appLocalizations.start,
      (true, true) => appLocalizations.suspended,
      (true, false) => appLocalizations.connected,
    };
    return Semantics(
      button: true,
      toggled: isStart,
      child: AnimatedContainer(
        height: _height,
        duration: duration,
        clipBehavior: Clip.antiAlias,
        decoration: ShapeDecoration(
          color: fill,
          shape: AppShape.full.copyWith(
            side: BorderSide(color: running ? fill : colorScheme.onSurface),
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            customBorder: AppShape.full,
            onTap: ref.read(commonActionProvider.notifier).toggleRunning,
            child: Padding(
              padding: const EdgeInsets.all(_knobInset),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  AnimatedAlign(
                    alignment: isStart
                        ? AlignmentDirectional.centerEnd
                        : AlignmentDirectional.centerStart,
                    duration: duration,
                    curve: Curves.easeOutCubic,
                    child: AnimatedContainer(
                      width: _knobSize,
                      height: _knobSize,
                      duration: duration,
                      decoration: ShapeDecoration(
                        color: foreground,
                        shape: AppShape.circle,
                      ),
                      child: Center(
                        child: isStart && suspend
                            ? GlyphIcon(AppGlyphs.wifiOff, color: fill, fill: 1)
                            : TweenAnimationBuilder<double>(
                                tween: Tween(end: isStart ? 1 : 0),
                                duration: context.motionDuration(
                                  _iconMorphDuration,
                                ),
                                curve: Curves.easeOutBack,
                                builder: (_, progress, _) => GlyphIcon(
                                  AppGlyphs.playPause(progress),
                                  color: fill,
                                  fill: 1,
                                ),
                              ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: _knobSize + _labelGap,
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            label,
                            style: context.textTheme.titleMedium?.toBold
                                .copyWith(color: foreground),
                          ),
                          if (isStart) _RunTime(color: foreground),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RunTime extends ConsumerWidget {
  const _RunTime({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Text(
      getTimeText(ref.watch(runTimeProvider)),
      style: context.textTheme.labelMedium?.toJetBrainsMono.copyWith(
        color: color,
      ),
    );
  }
}
