import 'package:flutter_test/flutter_test.dart';
import 'package:takeit/features/history/domain/entities/transfer_record.dart';

void main() {
  group('TransferRecord JSON', () {
    test('round-trips all fields', () {
      final original = TransferRecord(
        id: 't1',
        fileName: 'photo.jpg',
        fileSize: 4096,
        peerAlias: 'GrumpyPenguin',
        direction: 'received',
        timestamp: DateTime.parse('2026-06-30T08:30:00.000'),
        fileMimeType: 'image/jpeg',
        savePath: '/downloads/photo.jpg',
      );

      final decoded = TransferRecord.fromJson(original.toJson());
      expect(decoded.id, 't1');
      expect(decoded.fileName, 'photo.jpg');
      expect(decoded.fileSize, 4096);
      expect(decoded.peerAlias, 'GrumpyPenguin');
      expect(decoded.direction, 'received');
      expect(decoded.timestamp, original.timestamp);
      expect(decoded.fileMimeType, 'image/jpeg');
      expect(decoded.savePath, '/downloads/photo.jpg');
    });

    test('tolerates missing optional fields', () {
      final decoded = TransferRecord.fromJson({
        'id': 't2',
        'fileName': 'a.txt',
        'fileSize': 10,
        'peerAlias': 'X',
        'direction': 'sent',
        'timestamp': '2026-06-30T08:30:00.000',
      });
      expect(decoded.fileMimeType, isNull);
      expect(decoded.savePath, isNull);
    });
  });
}
