// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DeviceModel _$DeviceModelFromJson(Map<String, dynamic> json) => DeviceModel(
  fingerprint: json['fingerprint'] as String,
  alias: json['alias'] as String,
  deviceType: json['deviceType'] as String,
  ip: json['ip'] as String,
  port: (json['port'] as num).toInt(),
  os: json['os'] as String? ?? '',
);

Map<String, dynamic> _$DeviceModelToJson(DeviceModel instance) =>
    <String, dynamic>{
      'fingerprint': instance.fingerprint,
      'alias': instance.alias,
      'deviceType': instance.deviceType,
      'ip': instance.ip,
      'port': instance.port,
      'os': instance.os,
    };
