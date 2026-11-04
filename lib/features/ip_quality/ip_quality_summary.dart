import 'dart:math' as math;

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/providers/ip_quality.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/ui/ui.dart';
import 'package:fl_clash/ui/icons/icons.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ip_quality_sheet.dart';
import 'ip_quality_text.dart';
import 'labels.dart';

class IpQualitySummary extends ConsumerWidget {
  const IpQualitySummary({
    super.key,
    required this.ip,
    this.claude = false,
    this.exitLoading = false,
    this.exitFailed = false,
  });

  final String? ip;
  final bool claude;
  final bool exitLoading;
  final bool exitFailed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final address = ip;
    final result = address == null
        ? null
        : ref.watch(ipQualityProvider(address));
    final quality = result?.value;
    final localizations = context.appLocalizations;
    final scheme = context.colorScheme;
    final loading =
        exitLoading || (address != null && (result?.isLoading ?? false));
    final score = claude ? quality?.claudeTrustScore : quality?.trustScore;
    final title = claude
        ? localizations.claudeTrustScore
        : localizations.trustScore;
    final restricted = claude && quality?.isClaudeRegionRestricted == true;
    final color = switch (score) {
      final int value when value >= 80 => scheme.success,
      final int value when value >= 50 => scheme.primary,
      final int value when value >= 25 => scheme.warning,
      int() => scheme.error,
      null => scheme.onSurfaceVariant,
    };
    final flags = <(String, bool, String)>[
      (localizations.ipFlagVpn, quality?.isVpn ?? false, 'is_vpn'),
      (localizations.ipFlagProxy, quality?.isProxy ?? false, 'is_proxy'),
      (localizations.ipFlagTor, quality?.isTor ?? false, 'is_tor'),
      (localizations.ipFlagCrawler, quality?.isCrawler ?? false, 'is_crawler'),
      (localizations.ipFlagAbuser, quality?.isAbuser ?? false, 'is_abuser'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: AppTextStyle.subheadline.of(context, emphasized: true),
              ),
            ),
            TextButton(
              onPressed: address == null
                  ? null
                  : () => dialogs.openUrl(
                      'https://ip.net.coffee/ip/${Uri.encodeComponent(address)}',
                    ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 4,
                children: [
                  Text('Net.Coffee', style: AppTextStyle.caption1.of(context)),
                  const GlyphIcon(AppGlyphs.openExternal, size: 12),
                ],
              ),
            ),
          ],
        ),
        if (claude) ...[
          const SizedBox(height: 4),
          Text(
            localizations.claudeAssessmentHint,
            style: AppTextStyle.caption1
                .of(context)
                .copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
        const SizedBox(height: 12),
        Row(
          spacing: 16,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              label: '$title: ${score ?? '—'} / 100',
              child: SizedBox.square(
                dimension: 76,
                child: CustomPaint(
                  painter: _ScorePainter(score, color, scheme.outlineVariant),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${score ?? '—'}',
                            style: AppTextStyle.title1
                                .of(context, emphasized: true)
                                .toTabular
                                .copyWith(
                                  color: score == null
                                      ? scheme.onSurfaceVariant
                                      : color,
                                ),
                          ),
                          Text(
                            '/100',
                            style: AppTextStyle.caption2
                                .of(context)
                                .copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 7,
                children: [
                  Text(
                    score != null
                        ? restricted
                              ? localizations.claudeRestrictedRegion
                              : trustScoreLabel(context, score)
                        : loading
                        ? localizations.loading
                        : claude && exitFailed
                        ? localizations.claudeExitFailed
                        : address == null
                        ? localizations.servicePending
                        : localizations.ipQualityFailed,
                    style: AppTextStyle.headline
                        .of(context)
                        .copyWith(
                          color: score == null
                              ? scheme.onSurfaceVariant
                              : color,
                        ),
                  ),
                  Text(
                    quality?.type.label(context) ?? '—',
                    style: AppTextStyle.subheadline.of(context),
                  ),
                  Text(
                    [
                      if (quality?.asn case final asn?) 'AS$asn',
                      ?quality?.country,
                    ].join(' · '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyle.caption1
                        .of(context)
                        .copyWith(color: scheme.onSurfaceVariant),
                  ),
                  if (quality?.countryCode != null &&
                      quality?.registeredCountryCode != null)
                    Text(
                      quality!.countryCode == quality.registeredCountryCode
                          ? localizations.nativeIp
                          : localizations.broadcastIp,
                      style: AppTextStyle.caption1
                          .of(context)
                          .copyWith(color: scheme.onSurfaceVariant),
                    ),
                ],
              ),
            ),
          ],
        ),
        if (restricted && score != null) ...[
          const SizedBox(height: 12),
          Text(
            localizations.claudeRegionScoreHint,
            style: AppTextStyle.caption1
                .of(context)
                .copyWith(color: scheme.error),
          ),
        ],
        if (quality != null) ...[
          const SizedBox(height: 16),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final (label, detected, field) in flags)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 4,
                  ),
                  decoration: ShapeDecoration(
                    color: detected
                        ? scheme.warningContainer
                        : scheme.surfaceContainerHigh,
                    shape: AppShape.sm,
                  ),
                  child: Text(
                    '$label · ${detected
                        ? localizations.yes
                        : quality.reportedFlags.contains(field)
                        ? localizations.notDetected
                        : localizations.unknown}',
                    style: AppTextStyle.caption2
                        .of(context)
                        .copyWith(
                          color: detected
                              ? scheme.onWarningContainer
                              : scheme.onSurfaceVariant,
                        ),
                  ),
                ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        const Divider(),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: address == null
                  ? Text('—', style: AppTextStyle.caption1.of(context))
                  : IpQualityText(
                      ip: address,
                      style: AppTextStyle.caption1.of(context).toJetBrainsMono,
                    ),
            ),
            if (address != null)
              TextButton(
                onPressed: () => showIpQualitySheet(context, ip: address),
                child: Text(localizations.more),
              ),
          ],
        ),
      ],
    );
  }
}

class _ScorePainter extends CustomPainter {
  const _ScorePainter(this.score, this.color, this.track);

  final int? score;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(3);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2,
      false,
      paint..color = track.withValues(alpha: 0.55),
    );
    if (score case final value?) {
      canvas.drawArc(
        rect,
        -math.pi / 2,
        math.pi * 2 * value / 100,
        false,
        paint..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_ScorePainter oldDelegate) =>
      oldDelegate.score != score ||
      oldDelegate.color != color ||
      oldDelegate.track != track;
}
