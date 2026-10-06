import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/icons/icons.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/app.dart';
import 'package:fl_clash/views/dashboard/widget_metrics.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _minSpeedScale = 8 * 1024.0;
const _meterHeight = 42.0;
const _speedFontSize = 56.0;

class NetworkSpeed extends StatelessWidget {
  const NetworkSpeed({super.key});

  List<Color> _meterColors(ColorScheme colorScheme) {
    return [
      colorScheme.success,
      colorScheme.success,
      colorScheme.success,
      colorScheme.warning,
      colorScheme.warning,
      colorScheme.error,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final colorScheme = context.colorScheme;
    final mutedStyle = context.textTheme.bodySmall?.copyWith(
      color: colorScheme.onSurfaceVariant,
    );
    return SizedBox(
      height: DashboardWidgetMetrics.heightOf(context, 2),
      child: RepaintBoundary(
        child: CommonCard(
          radius: DashboardWidgetMetrics.radiusOf(context),
          onPressed: () {},
          child: Consumer(
            builder: (_, ref, _) {
              final traffics = ref.watch(trafficsProvider);
              final current = traffics.list.safeLast(const Traffic());
              final down = current.down.traffic;
              return Padding(
                padding: DashboardWidgetMetrics.paddingOf(context),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: InfoHeader(
                            padding: EdgeInsets.zero,
                            info: Info(
                              label: appLocalizations.networkSpeed,
                              glyph: AppGlyphs.speed,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '↑ ${current.up.traffic.show}/s',
                          style: mutedStyle,
                        ),
                      ],
                    ),
                    Expanded(
                      child: Align(
                        alignment: AlignmentDirectional.bottomStart,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: AlignmentDirectional.bottomStart,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                down.value,
                                style: TextStyle(
                                  fontSize: _speedFontSize,
                                  height: 1,
                                  color: colorScheme.onSurface,
                                ).toDoto,
                              ),
                              const SizedBox(width: 8),
                              Text('↓ ${down.unit}/s', style: mutedStyle),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: _meterHeight,
                      child: DotMeter(
                        values: [
                          for (final traffic in traffics.list)
                            traffic.speed.toDouble(),
                        ],
                        capacity: traffics.maxLength,
                        minScale: _minSpeedScale,
                        colors: _meterColors(colorScheme),
                        unlitColor: colorScheme.surfaceContainerHighest,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
