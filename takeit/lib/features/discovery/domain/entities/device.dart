import 'package:freezed_annotation/freezed_annotation.dart';

part 'device.freezed.dart';

@freezed
class Device with _$Device {
  const factory Device({
    required String fingerprint,
    required String alias,
    required String deviceType,
    required String ip,
    required int port,
    required DateTime lastSeen,
    @Default('') String os,
  }) = _Device;
}
