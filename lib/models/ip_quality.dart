import 'package:fl_clash/enum/enum.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'generated/ip_quality.freezed.dart';
part 'generated/ip_quality.g.dart';

@freezed
abstract class IpQuality with _$IpQuality {
  const factory IpQuality({
    required String ip,
    required IpQualitySource source,
    required IpType type,
    String? organization,
    int? asn,
    int? trustScore,
    String? country,
    String? countryCode,
    String? registeredCountryCode,
    @Default(false) bool isCrawler,
    @Default([]) List<String> reportedFlags,
    @Default(false) bool isProxy,
    @Default(false) bool isVpn,
    @Default(false) bool isTor,
    @Default(false) bool isAbuser,
  }) = _IpQuality;

  factory IpQuality.fromJson(Map<String, Object?> json) =>
      _$IpQualityFromJson(json);
}

extension IpQualityExt on IpQuality {
  // Net.Coffee Claude region policy: https://ip.net.coffee/claude/claude-page.js (2026-11-04).
  bool get isClaudeRegionRestricted => const {
    'CN',
    'HK',
    'MO',
    'RU',
    'KP',
    'IR',
    'SY',
    'CU',
    'BY',
    'VE',
  }.contains(countryCode?.toUpperCase());

  int? get claudeTrustScore => trustScore == null
      ? null
      : isClaudeRegionRestricted
      ? 0
      : trustScore;

  IpQualityLevel get level {
    if (trustScore case final score?) {
      return score >= 50
          ? IpQualityLevel.good
          : score >= 25
          ? IpQualityLevel.normal
          : IpQualityLevel.risky;
    }
    if (isTor || isAbuser) {
      return IpQualityLevel.risky;
    }
    return switch (type) {
      IpType.residential ||
      IpType.mobile ||
      IpType.business => IpQualityLevel.good,
      IpType.hosting || IpType.unknown => IpQualityLevel.normal,
    };
  }
}
