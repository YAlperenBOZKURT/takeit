import 'package:flutter_test/flutter_test.dart';
import 'package:takeit/features/chat/domain/entities/message.dart';

void main() {
  group('Message JSON', () {
    test('round-trips a plain text message', () {
      final original = Message(
        id: 'm1',
        roomId: 'r1',
        senderId: 'dev1',
        senderAlias: 'LazySloth',
        content: 'hello',
        timestamp: DateTime.parse('2026-01-01T12:00:00.000'),
      );

      final decoded = Message.fromJson(original.toJson());
      expect(decoded.id, 'm1');
      expect(decoded.content, 'hello');
      expect(decoded.type, MessageType.text);
      expect(decoded.timestamp, original.timestamp);
    });

    test('round-trips a file-meta message with optional fields', () {
      final original = Message(
        id: 'm2',
        roomId: 'r1',
        senderId: 'dev1',
        senderAlias: 'LazySloth',
        content: 'sent a file',
        timestamp: DateTime.parse('2026-01-01T12:00:00.000'),
        type: MessageType.fileMeta,
        fileName: 'doc.pdf',
        fileSize: 2048,
        fileMimeType: 'application/pdf',
      );

      final decoded = Message.fromJson(original.toJson());
      expect(decoded.type, MessageType.fileMeta);
      expect(decoded.fileName, 'doc.pdf');
      expect(decoded.fileSize, 2048);
      expect(decoded.fileMimeType, 'application/pdf');
    });

    test('defaults type to text and leaves file fields null', () {
      final decoded = Message.fromJson({
        'id': 'm3',
        'roomId': 'r1',
        'senderId': 'dev1',
        'senderAlias': 'A',
        'content': 'hi',
        'timestamp': '2026-01-01T12:00:00.000',
      });
      expect(decoded.type, MessageType.text);
      expect(decoded.fileName, isNull);
      expect(decoded.fileSize, isNull);
    });
  });
}
