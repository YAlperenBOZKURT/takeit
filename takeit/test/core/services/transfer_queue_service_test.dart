import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:takeit/core/services/transfer_queue_service.dart';

TransferBatch _batch(
  String id, {
  String sender = 'sender-a',
  Duration approvalTimeout = kApprovalTimeout,
}) => TransferBatch(
  batchId: id,
  senderId: sender,
  senderAlias: sender,
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
