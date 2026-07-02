import '../../data/services/file_transfer_service.dart';

class SendFile {
  final FileTransferService _service;

  SendFile(this._service);

  Future<void> call({
    required String targetIp,
    required int targetPort,
    required String filePath,
    required String sessionId,
    required String fileId,
    required String token,
    required void Function(int sent, int total) onProgress,
  }) {
    return _service.sendFile(
      targetIp: targetIp,
      targetPort: targetPort,
      filePath: filePath,
      sessionId: sessionId,
      fileId: fileId,
      token: token,
      onProgress: onProgress,
    );
  }
}
