import 'package:fpdart/fpdart.dart';
import '../../../../core/error/failures.dart';

abstract class LeaveRoomRepository {
  Future<Either<Failure, void>> leaveRoom(String roomId);
}

class LeaveRoom {
  final LeaveRoomRepository _repository;

  LeaveRoom(this._repository);

  Future<Either<Failure, void>> call(String roomId) {
    return _repository.leaveRoom(roomId);
  }
}
