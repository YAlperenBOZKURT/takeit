import '../entities/device.dart';

abstract class DiscoveryRepository {
  Stream<List<Device>> get devicesStream;
  Future<void> startDiscovery({
    required String alias,
    required String deviceType,
    required String fingerprint,
    required int port,
    String os = '',
  });
  Future<void> stopDiscovery();
  void reAnnounce();

  /// Switch announcements to [alias] (nickname changed while running).
  void updateAlias(String alias);
  void registerDevice(Device device);
}
