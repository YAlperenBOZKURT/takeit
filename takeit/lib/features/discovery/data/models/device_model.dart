import 'package:json_annotation/json_annotation.dart';
import '../../domain/entities/device.dart';

part 'device_model.g.dart';

@JsonSerializable()
class DeviceModel {
  final String fingerprint;
  final String alias;
  final String deviceType;
  final String ip;
  final int port;
  final String os;

  const DeviceModel({
    required this.fingerprint,
    required this.alias,
    required this.deviceType,
    required this.ip,
    required this.port,
    this.os = '',
  });

  factory DeviceModel.fromJson(Map<String, dynamic> json) =>
      _$DeviceModelFromJson(json);

  Map<String, dynamic> toJson() => _$DeviceModelToJson(this);

  Device toEntity() => Device(
    fingerprint: fingerprint,
    alias: alias,
    deviceType: deviceType,
    ip: ip,
    port: port,
    lastSeen: DateTime.now(),
    os: os,
  );
}
