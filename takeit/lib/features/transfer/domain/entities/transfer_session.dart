import 'package:freezed_annotation/freezed_annotation.dart';

part 'transfer_session.freezed.dart';

enum TransferStatus {
  pending,
  accepted,
  declined,
  inProgress,
  completed,
  failed,
  cancelled,
}

enum TransferDirection { sending, receiving }

@freezed
class TransferSession with _$TransferSession {
  const factory TransferSession({
    required String sessionId,
    required String fileId,
    required String fileName,
    required int fileSize,
    required String senderId,
    required String senderAlias,
    required TransferDirection direction,
    @Default(TransferStatus.pending) TransferStatus status,
    @Default(0) int bytesTransferred,
    String? fileMimeType,
    String? token,
    String? savePath,
    DateTime? startedAt,
  }) = _TransferSession;

  const TransferSession._();

  double get progress => fileSize > 0 ? bytesTransferred / fileSize : 0;

  /// Bytes per second
  double get speed {
    if (startedAt == null || bytesTransferred == 0) return 0;
    final elapsed = DateTime.now().difference(startedAt!).inMilliseconds;
    if (elapsed <= 0) return 0;
    return bytesTransferred / (elapsed / 1000);
  }

  /// Estimated remaining duration
  Duration? get eta {
    if (speed <= 0 || progress >= 1) return null;
    final remaining = fileSize - bytesTransferred;
    return Duration(seconds: (remaining / speed).round());
  }
}
