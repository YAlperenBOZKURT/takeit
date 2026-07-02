import '../../../../core/network/multicast_service.dart';
import '../models/device_model.dart';

class MulticastDatasource {
  final MulticastService _multicastService;

  MulticastDatasource(this._multicastService);

  Stream<DeviceModel> get deviceStream => _multicastService.messages.map(
    (msg) => DeviceModel(
      fingerprint: msg.fingerprint,
      alias: msg.alias,
      deviceType: msg.deviceType,
      ip: msg.ip,
      port: msg.port,
      os: msg.os,
    ),
  );

  void announce(MulticastMessage message) {
    _multicastService.announce(message);
  }

  void startHeartbeat(MulticastMessage message) {
    _multicastService.startHeartbeat(message);
  }

  void stopHeartbeat() {
    _multicastService.stopHeartbeat();
  }
}
