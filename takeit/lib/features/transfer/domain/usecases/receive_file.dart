import '../../data/services/file_transfer_service.dart';

class ReceiveFile {
  final FileTransferService _service;

  ReceiveFile(this._service);

  Future<String> reservePartFile(String fileName, {String? customDir}) {
    return _service.reservePartFile(fileName, customDir: customDir);
  }
}
