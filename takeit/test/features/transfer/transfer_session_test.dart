import 'package:flutter_test/flutter_test.dart';
import 'package:takeit/features/transfer/domain/entities/transfer_session.dart';

TransferSession _session({
  int fileSize = 1000,
  int bytesTransferred = 0,
  DateTime? startedAt,
}) {
  return TransferSession(
    sessionId: 's1',
    fileId: 'f1',
    fileName: 'photo.jpg',
    fileSize: fileSize,
    senderId: 'dev1',
    senderAlias: 'LazySloth',
    direction: TransferDirection.receiving,
    bytesTransferred: bytesTransferred,
    startedAt: startedAt,
  );
}

void main() {
  group('TransferSession.progress', () {
    test('is 0 when nothing transferred', () {
      expect(_session(bytesTransferred: 0).progress, 0);
    });

    test('is a ratio of bytes to size', () {
      expect(_session(fileSize: 1000, bytesTransferred: 250).progress, 0.25);
    });

    test('is 1.0 when complete', () {
      expect(_session(fileSize: 1000, bytesTransferred: 1000).progress, 1.0);
    });

    test('guards against division by zero for empty files', () {
      expect(_session(fileSize: 0, bytesTransferred: 0).progress, 0);
    });
  });

  group('TransferSession.speed', () {
    test('is 0 before transfer starts', () {
      expect(_session(startedAt: null).speed, 0);
    });

    test('is 0 when no bytes transferred yet', () {
      expect(_session(bytesTransferred: 0, startedAt: DateTime.now()).speed, 0);
    });

    test('computes bytes per second from elapsed time', () {
      final started = DateTime.now().subtract(const Duration(seconds: 2));
      final speed = _session(bytesTransferred: 1000, startedAt: started).speed;
      // ~500 B/s; allow generous slack for test-runner timing jitter.
      expect(speed, greaterThan(100));
      expect(speed, lessThan(1000));
    });
  });

  group('TransferSession.eta', () {
    test('is null when there is no measurable speed', () {
      expect(_session(startedAt: null).eta, isNull);
    });

    test('is null when already complete', () {
      final started = DateTime.now().subtract(const Duration(seconds: 1));
      final s = _session(
        fileSize: 1000,
        bytesTransferred: 1000,
        startedAt: started,
      );
      expect(s.eta, isNull);
    });

    test('returns a positive duration mid-transfer', () {
      final started = DateTime.now().subtract(const Duration(seconds: 1));
      final s = _session(
        fileSize: 1000,
        bytesTransferred: 500,
        startedAt: started,
      );
      expect(s.eta, isNotNull);
      expect(s.eta!.inMilliseconds, greaterThan(0));
    });
  });
}
