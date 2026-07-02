import 'package:fpdart/fpdart.dart';
import '../../../../core/error/failures.dart';
import '../../../discovery/domain/entities/device.dart';
import '../entities/room.dart';

abstract class CreateRoomRepository {
  Future<Either<Failure, Room>> createRoom(List<Device> selectedDevices);
}

class CreateRoom {
  final CreateRoomRepository _repository;

  CreateRoom(this._repository);

  Future<Either<Failure, Room>> call(List<Device> selectedDevices) {
    return _repository.createRoom(selectedDevices);
  }
}
