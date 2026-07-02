abstract class Failure {
  final String message;
  const Failure(this.message);

  @override
  String toString() => message;
}

class NetworkFailure extends Failure {
  const NetworkFailure(super.message);
}

class ServerFailure extends Failure {
  const ServerFailure(super.message);
}

class FileFailure extends Failure {
  const FileFailure(super.message);
}

class RoomFailure extends Failure {
  const RoomFailure(super.message);
}
