import 'package:freezed_annotation/freezed_annotation.dart';

part 'transfer_record.freezed.dart';
part 'transfer_record.g.dart';

@freezed
class TransferRecord with _$TransferRecord {
  const factory TransferRecord({
    required String id,
    required String fileName,
    required int fileSize,
    required String peerAlias,
    required String direction, // 'sent' or 'received'
    required DateTime timestamp,
    String? fileMimeType,
    String? savePath,
  }) = _TransferRecord;

  factory TransferRecord.fromJson(Map<String, dynamic> json) =>
      _$TransferRecordFromJson(json);
}
