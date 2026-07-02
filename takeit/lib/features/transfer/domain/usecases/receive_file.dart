import '../../data/services/file_transfer_service.dart';

class ReceiveFile {
  final FileTransferService _service;

  ReceiveFile(this._service);

  Future<String> getSavePath(String fileName, {String? customDir}) {
    return _service.getSavePath(fileName, customDir: customDir);
  }
}
