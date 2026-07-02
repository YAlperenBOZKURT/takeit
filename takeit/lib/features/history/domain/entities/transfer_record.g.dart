// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transfer_record.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$TransferRecordImpl _$$TransferRecordImplFromJson(Map<String, dynamic> json) =>
    _$TransferRecordImpl(
      id: json['id'] as String,
      fileName: json['fileName'] as String,
      fileSize: (json['fileSize'] as num).toInt(),
      peerAlias: json['peerAlias'] as String,
      direction: json['direction'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      fileMimeType: json['fileMimeType'] as String?,
      savePath: json['savePath'] as String?,
    );

Map<String, dynamic> _$$TransferRecordImplToJson(
  _$TransferRecordImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'fileName': instance.fileName,
  'fileSize': instance.fileSize,
  'peerAlias': instance.peerAlias,
  'direction': instance.direction,
  'timestamp': instance.timestamp.toIso8601String(),
  'fileMimeType': instance.fileMimeType,
  'savePath': instance.savePath,
};
