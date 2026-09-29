import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:takeit/core/services/transfer_queue_service.dart';
import 'package:takeit/features/discovery/presentation/providers/device_actions_provider.dart';

TransferBatch _batch(
  String id, {
  String sender = 'sender-a',
  String ip = '192.168.1.10',
  Duration approvalTimeout = kApprovalTimeout,
}) => TransferBatch(
  batchId: id,
  senderId: sender,
  senderAlias: sender,
  senderIp: ip,
  source: TransferSource.room,
  files: [BatchedFile(fileName: '$id.bin', fileSize: 1)..sessionId = '$id-s'],
  approvalCompleter: Completer<List<bool>>(),
  approvalTimeout: approvalTimeout,
);

void main() {
  late ProviderContainer container;
  late TransferQueueService queue;

  setUp(() {
    container = ProviderContainer();
    queue = container.read(transferQueueProvider);
  });

  tearDown(() => container.dispose());

  TransferBatch? current() => container.read(currentApprovalProvider);

  test('sender waits longer for prepare-batch than the approval window', () {
    expect(kPrepareResponseTimeout, greaterThan(kApprovalTimeout));
  });

  group('trust and block', () {
    test('a trusted device is auto-accepted', () async {
      container
          .read(trustedDevicesProvider.notifier)
          .add('sender-a', '192.168.1.10');

      expect(await queue.enqueueBatch(_batch('a')), [true]);
      expect(current(), isNull);
    });

    test('a trusted fingerprint from another IP still needs approval', () {
      container
          .read(trustedDevicesProvider.notifier)
          .add('sender-a', '192.168.1.10');

      final spoofed = _batch('a', ip: '192.168.1.66');
      unawaited(queue.enqueueBatch(spoofed));

      expect(current(), same(spoofed), reason: 'must ask, not auto-accept');
      queue.declineAllCurrent();
    });

    test('a blocked device is declined even under a new fingerprint', () async {
      container
          .read(blockedDevicesProvider.notifier)
          .add('sender-a', '192.168.1.10');

      expect(await queue.enqueueBatch(_batch('a', sender: 'fresh-fp')), [
        false,
      ]);
      expect(current(), isNull);
    });
  });

  group('download slots', () {
    test('a waiting upload starts as soon as a slot frees up', () async {
      for (var i = 0; i < TransferQueueService.maxParallelDownloads; i++) {
        expect(await queue.waitForDownloadSlot('busy-$i'), isTrue);
      }

      var started = false;
      final waiting = queue
          .waitForDownloadSlot('next')
          .then((ok) => started = ok);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(started, isFalse, reason: 'all slots are taken');

      final freedAt = DateTime.now();
      queue.downloadCompleted('busy-0', senderAlias: 'x');
      await waiting;

      expect(started, isTrue);
      expect(
        DateTime.now().difference(freedAt),
        lessThan(const Duration(milliseconds: 200)),
        reason: 'woken right away, not on the next poll',
      );
    });

    test('a waiting upload gives up after its timeout', () async {
      for (var i = 0; i < TransferQueueService.maxParallelDownloads; i++) {
        await queue.waitForDownloadSlot('busy-$i');
      }

      final ok = await queue.waitForDownloadSlot(
        'next',
        timeout: const Duration(milliseconds: 100),
      );

      expect(ok, isFalse);
    });
  });

  test('only the sending device can cancel its pending batch', () async {
    final a = _batch('a', ip: '192.168.1.10');
    final result = queue.enqueueBatch(a);

    queue.cancelBatch('a', fromIp: '192.168.1.66');
    expect(current(), same(a), reason: 'cancel from another device ignored');

    queue.cancelBatch('a', fromIp: '192.168.1.10');
    expect(await result, [false]);
    expect(current(), isNull);
  });

  test('user approval resolves the batch and clears the dialog', () async {
    final a = _batch('a');
    final result = queue.enqueueBatch(a);
    expect(current(), same(a));

    queue.acceptAllCurrent();

    expect(await result, [true]);
    expect(current(), isNull);
  });

  test(
    'timed-out batch that is on screen is declined and its dialog closed',
    () async {
      final a = _batch('a', approvalTimeout: const Duration(milliseconds: 80));
      final result = queue.enqueueBatch(a);
      expect(current(), same(a));

      expect(await result, [false]);
      expect(current(), isNull, reason: 'stale dialog must not stay open');
    },
  );

  test('timed-out batch hands the dialog to the next queued batch', () async {
    final a = _batch('a', approvalTimeout: const Duration(milliseconds: 80));
    final b = _batch('b', sender: 'sender-b');
    final aResult = queue.enqueueBatch(a);
    unawaited(queue.enqueueBatch(b));
    expect(current(), same(a));

    expect(await aResult, [false]);
    expect(current(), same(b));

    queue.declineAllCurrent();
  });

  test(
    'a queued batch timing out does not replace the one on screen',
    () async {
      final a = _batch('a');
      final b = _batch(
        'b',
        sender: 'sender-b',
        approvalTimeout: const Duration(milliseconds: 80),
      );
      final aResult = queue.enqueueBatch(a);
      final bResult = queue.enqueueBatch(b);
      expect(current(), same(a));
      expect(container.read(queueDepthProvider), 1);

      expect(await bResult, [false]);
      expect(current(), same(a), reason: 'dialog for a must stay up');
      expect(container.read(queueDepthProvider), 0);

      queue.acceptAllCurrent();
      expect(await aResult, [true]);
    },
  );
}
