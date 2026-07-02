import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../quick_send/presentation/providers/quick_send_provider.dart';
import '../../domain/entities/transfer_session.dart';
import 'transfer_provider.dart';

/// Where a transfer originated from — affects which notifier handles cancellation.
enum TransferOrigin { room, quick }

class SessionTransferView {
  final TransferSession session;
  final TransferOrigin origin;

  const SessionTransferView({required this.session, required this.origin});

  String get sessionId => session.sessionId;
  bool get isActive =>
      session.status == TransferStatus.inProgress ||
      session.status == TransferStatus.pending ||
      session.status == TransferStatus.accepted;
  bool get isCompleted => session.status == TransferStatus.completed;
  bool get isFailed =>
      session.status == TransferStatus.failed ||
      session.status == TransferStatus.cancelled ||
      session.status == TransferStatus.declined;
}

/// Combined view of all transfers (room + quick) for the current app session.
/// Empty on fresh app start — accumulates as user sends/receives.
final sessionTransfersProvider = Provider<List<SessionTransferView>>((ref) {
  final roomTransfers = ref.watch(transferProvider);
  final quickTransfers = ref.watch(quickTransfersProvider);

  return [
    ...roomTransfers.map(
      (s) => SessionTransferView(session: s, origin: TransferOrigin.room),
    ),
    ...quickTransfers.map(
      (s) => SessionTransferView(session: s, origin: TransferOrigin.quick),
    ),
  ].reversed.toList();
});

/// Number of transfers currently in flight.
final activeTransferCountProvider = Provider<int>((ref) {
  final all = ref.watch(sessionTransfersProvider);
  return all.where((t) => t.isActive).length;
});
