import 'package:flutter_test/flutter_test.dart';
import 'package:takeit/core/error/failures.dart';
import 'package:takeit/core/error/exceptions.dart';

void main() {
  group('Failure', () {
    test('toString returns the message', () {
      expect(const NetworkFailure('offline').toString(), 'offline');
      expect(const ServerFailure('boom').toString(), 'boom');
      expect(const FileFailure('bad file').toString(), 'bad file');
      expect(const RoomFailure('full').toString(), 'full');
    });

    test('subtypes are all Failures', () {
      expect(const NetworkFailure('x'), isA<Failure>());
      expect(const ServerFailure('x'), isA<Failure>());
      expect(const FileFailure('x'), isA<Failure>());
      expect(const RoomFailure('x'), isA<Failure>());
    });
  });

  group('Exceptions', () {
    test('toString is prefixed with the type', () {
      expect(
        const NetworkException('timeout').toString(),
        'NetworkException: timeout',
      );
      expect(const ServerException('500').toString(), 'ServerException: 500');
      expect(
        const FileException('missing').toString(),
        'FileException: missing',
      );
    });

    test('implement Exception', () {
      expect(const NetworkException('x'), isA<Exception>());
      expect(const ServerException('x'), isA<Exception>());
      expect(const FileException('x'), isA<Exception>());
    });
  });
}
