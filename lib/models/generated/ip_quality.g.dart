// GENERATED CODE - DO NOT MODIFY BY HAND

part of '../ip_quality.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_IpQuality _$IpQualityFromJson(Map<String, dynamic> json) => _IpQuality(
  ip: json['ip'] as String,
  source: $enumDecode(_$IpQualitySourceEnumMap, json['source']),
  type: $enumDecode(_$IpTypeEnumMap, json['type']),
  organization: json['organization'] as String?,
  asn: (json['asn'] as num?)?.toInt(),
  trustScore: (json['trustScore'] as num?)?.toInt(),
  country: json['country'] as String?,
  countryCode: json['countryCode'] as String?,
  registeredCountryCode: json['registeredCountryCode'] as String?,
  isCrawler: json['isCrawler'] as bool? ?? false,
  reportedFlags:
      (json['reportedFlags'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ??
      const [],
  isProxy: json['isProxy'] as bool? ?? false,
  isVpn: json['isVpn'] as bool? ?? false,
  isTor: json['isTor'] as bool? ?? false,
  isAbuser: json['isAbuser'] as bool? ?? false,
);

Map<String, dynamic> _$IpQualityToJson(_IpQuality instance) =>
    <String, dynamic>{
      'ip': instance.ip,
      'source': _$IpQualitySourceEnumMap[instance.source]!,
      'type': _$IpTypeEnumMap[instance.type]!,
      'organization': instance.organization,
      'asn': instance.asn,
      'trustScore': instance.trustScore,
      'country': instance.country,
      'countryCode': instance.countryCode,
      'registeredCountryCode': instance.registeredCountryCode,
      'isCrawler': instance.isCrawler,
      'reportedFlags': instance.reportedFlags,
      'isProxy': instance.isProxy,
      'isVpn': instance.isVpn,
      'isTor': instance.isTor,
      'isAbuser': instance.isAbuser,
    };

const _$IpQualitySourceEnumMap = {
  IpQualitySource.identMe: 'identMe',
  IpQualitySource.ipApiCom: 'ipApiCom',
  IpQualitySource.ipQuery: 'ipQuery',
  IpQualitySource.ipLocate: 'ipLocate',
  IpQualitySource.proxyCheck: 'proxyCheck',
  IpQualitySource.ipApiIs: 'ipApiIs',
  IpQualitySource.netCoffee: 'netCoffee',
};

const _$IpTypeEnumMap = {
  IpType.residential: 'residential',
  IpType.mobile: 'mobile',
  IpType.business: 'business',
  IpType.hosting: 'hosting',
  IpType.unknown: 'unknown',
};
