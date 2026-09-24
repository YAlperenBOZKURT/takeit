import 'package:flutter_test/flutter_test.dart';
import 'package:takeit/core/services/batch_idle_expiry.dart';

void main() {
  const timeout = Duration(milliseconds: 100);
  const pastTimeout = Duration(milliseconds: 180);

  late List<String> expired;
  late BatchIdleExpiry expiry;

  setUp(() {
    expired = [];
    expiry = BatchIdleExpiry(idleTimeout: timeout, onExpire: expired.add);
  });

  tearDown(() => expiry.dispose());

  test(
    'an armed batch with no uploads expires after the idle timeout',
    () async {
      expiry.arm('b1');
      await Future<void>.delayed(pastTimeout);
      expect(expired, ['b1']);
    },
  );

  test('a running upload pauses the countdown however long it takes', () async {
    expiry.arm('b1');
    expiry.uploadStarted('b1');
    await Future<void>.delayed(pastTimeout * 2);
    expect(expired, isEmpty);
  });

  test('countdown restarts from zero once the last upload ends', () async {
    expiry.arm('b1');
    expiry.uploadStarted('b1');
    await Future<void>.delayed(pastTimeout);
    expiry.uploadEnded('b1');

    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(expired, isEmpty, reason: 'fresh window after the upload ended');

    await Future<void>.delayed(pastTimeout);
    expect(expired, ['b1']);
  });

  test(
    'overlapping uploads keep the batch alive until all have ended',
    () async {
      expiry.arm('b1');
      expiry.uploadStarted('b1');
      expiry.uploadStarted('b1');
      expiry.uploadEnded('b1');
      await Future<void>.delayed(pastTimeout);
      expect(expired, isEmpty);

      expiry.uploadEnded('b1');
      await Future<void>.delayed(pastTimeout);
      expect(expired, ['b1']);
    },
  );

  test('re-arming an idle batch pushes the deadline back', () async {
    expiry.arm('b1');
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expiry.arm('b1');
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(expired, isEmpty);

    await Future<void>.delayed(pastTimeout);
    expect(expired, ['b1']);
  });

  test('forget cancels a pending expiry', () async {
    expiry.arm('b1');
    expiry.forget('b1');
    await Future<void>.delayed(pastTimeout);
    expect(expired, isEmpty);
  });

  test('batches expire independently', () async {
    expiry.arm('b1');
    expiry.arm('b2');
    expiry.uploadStarted('b2');
    await Future<void>.delayed(pastTimeout);
    expect(expired, ['b1']);
  });
}
