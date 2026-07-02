import 'package:freezed_annotation/freezed_annotation.dart';

part 'message.freezed.dart';
part 'message.g.dart';

enum MessageType { text, fileMeta, clipboard }

@freezed
class Message with _$Message {
  const factory Message({
    required String id,
    required String roomId,
    required String senderId,
    required String senderAlias,
    required String content,
    required DateTime timestamp,
    @Default(MessageType.text) MessageType type,
    // file metadata (only used when type == fileMeta)
    String? fileName,
    int? fileSize,
    String? fileMimeType,
    String? savePath,
  }) = _Message;

  factory Message.fromJson(Map<String, dynamic> json) =>
      _$MessageFromJson(json);
}
