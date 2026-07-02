import 'package:fpdart/fpdart.dart';
import '../../../../core/error/failures.dart';

abstract class JoinRoomRepository {
  Future<Either<Failure, void>> acceptInvite({
    required String roomId,
    required String hostIp,
    required int hostPort,
  });
  Future<Either<Failure, void>> declineInvite({
    required String roomId,
    required String hostIp,
    required int hostPort,
  });
}

class JoinRoom {
  final JoinRoomRepository _repository;

  JoinRoom(this._repository);

  Future<Either<Failure, void>> accept({
    required String roomId,
    required String hostIp,
    required int hostPort,
  }) {
    return _repository.acceptInvite(
      roomId: roomId,
      hostIp: hostIp,
      hostPort: hostPort,
    );
  }

  Future<Either<Failure, void>> decline({
    required String roomId,
    required String hostIp,
    required int hostPort,
  }) {
    return _repository.declineInvite(
      roomId: roomId,
      hostIp: hostIp,
      hostPort: hostPort,
    );
  }
}
