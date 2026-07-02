import '../repositories/discovery_repository.dart';

class StartDiscovery {
  final DiscoveryRepository _repository;

  StartDiscovery(this._repository);

  Future<void> call({
    required String alias,
    required String deviceType,
    required String fingerprint,
    required int port,
  }) {
    return _repository.startDiscovery(
      alias: alias,
      deviceType: deviceType,
      fingerprint: fingerprint,
      port: port,
    );
  }
}
