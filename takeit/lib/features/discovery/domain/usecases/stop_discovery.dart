import '../repositories/discovery_repository.dart';

class StopDiscovery {
  final DiscoveryRepository _repository;

  StopDiscovery(this._repository);

  Future<void> call() {
    return _repository.stopDiscovery();
  }
}
