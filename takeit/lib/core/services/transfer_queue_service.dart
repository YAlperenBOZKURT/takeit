import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/discovery/presentation/providers/device_actions_provider.dart';

/// Source of a transfer request (room chat or quick send).
enum TransferSource { room, quick }

/// A single file inside a batch awaiting approval.
class BatchedFile {
  final String fileName;
  final int fileSize;
  final String? fileMimeType;

  /// Assigned by the receiver once approved (null when declined).
  String? sessionId;
  String? fileId;
  String? token;

  BatchedFile({
    required this.fileName,
    required this.fileSize,
    this.fileMimeType,
  });
}

/// A group of incoming files from the same sender, approved/declined as a unit.
class TransferBatch {
  final String batchId;
  final String senderId;
  final String senderAlias;
  final String? senderIp;
  final TransferSource source;
  final List<BatchedFile> files;

  /// Completes with a `List<bool>` of the same length as [files]. True = accept.
  final Completer<List<bool>> approvalCompleter;
  final DateTime enqueuedAt;

  TransferBatch({
    required this.batchId,
    required this.senderId,
    required this.senderAlias,
    this.senderIp,
    required this.source,
    required this.files,
    required this.approvalCompleter,
  }) : enqueuedAt = DateTime.now();

  bool get isExpired =>
      DateTime.now().difference(enqueuedAt) > const Duration(seconds: 120);
}

/// The batch currently shown in the approval dialog.
final currentApprovalProvider = StateProvider<TransferBatch?>((ref) => null);

/// Count of batches waiting behind the current approval.
final queueDepthProvider = StateProvider<int>((ref) => 0);

/// IDs of currently downloading transfers (for progress tracking).
final activeDownloadIdsProvider = StateProvider<Set<String>>((ref) => {});

/// Global transfer queue — ensures one download at a time with fair scheduling.
final transferQueueProvider = Provider<TransferQueueService>((ref) {
  return TransferQueueService(ref);
});

class TransferQueueService {
  final Ref _ref;

  /// All queued batches, not yet approved.
  final List<TransferBatch> _pendingQueue = [];

  static const int maxParallelDownloads = 3;

  /// Approved session IDs waiting for a download slot.
  final Set<String> _approvedWaiting = {};

  /// Currently downloading transfer IDs.
  final Set<String> _activeDownloadIds = {};

  /// Tracks which senders we've served recently for round-robin.
  final List<String> _recentSenders = [];

  bool _showingApproval = false;

  TransferQueueService(this._ref);

  /// Enqueue a batch of incoming files. Returns per-file accepted list.
  /// The caller (prepare-batch handler) awaits this — it blocks the HTTP response.
  Future<List<bool>> enqueueBatch(TransferBatch batch) async {
    // Session-based block: silently reject all files in the batch
    final blocked = _ref.read(blockedDevicesProvider);
    if (blocked.contains(batch.senderId)) {
      debugPrint('Batch from ${batch.senderAlias} blocked (session)');
      return List.filled(batch.files.length, false);
    }

    // Session-based trust: auto-accept without dialog
    final trusted = _ref.read(trustedDevicesProvider);
    if (trusted.contains(batch.senderId)) {
      debugPrint('Batch from ${batch.senderAlias} auto-accepted (trusted)');
      for (final f in batch.files) {
        if (f.sessionId != null) _approvedWaiting.add(f.sessionId!);
      }
      return List.filled(batch.files.length, true);
    }

    _pendingQueue.add(batch);
    _updateDepthCount();
    _processApprovalQueue();

    // Timeout — auto-decline if user doesn't respond
    final timer = Timer(const Duration(seconds: 120), () {
      if (!batch.approvalCompleter.isCompleted) {
        debugPrint('Batch ${batch.batchId} timed out waiting for approval');
        batch.approvalCompleter.complete(
          List.filled(batch.files.length, false),
        );
        _pendingQueue.removeWhere((q) => q.batchId == batch.batchId);
        _showingApproval = false;
        _updateDepthCount();
        _processApprovalQueue();
      }
    });

    final results = await batch.approvalCompleter.future;
    timer.cancel();

    // Track accepted sessions as waiting-for-download
    for (var i = 0; i < batch.files.length; i++) {
      if (results[i]) {
        final sid = batch.files[i].sessionId;
        if (sid != null) _approvedWaiting.add(sid);
      }
    }
    return results;
  }

  /// Called when the user resolves the batch (checkbox selections → per-file bool).
  void resolveCurrent(List<bool> perFileAccepted) {
    final current = _ref.read(currentApprovalProvider);
    if (current == null) return;
    if (!current.approvalCompleter.isCompleted) {
      // Pad/truncate to file count for safety.
      final resolved = List<bool>.generate(
        current.files.length,
        (i) => i < perFileAccepted.length ? perFileAccepted[i] : false,
      );
      current.approvalCompleter.complete(resolved);
    }
    _pendingQueue.removeWhere((q) => q.batchId == current.batchId);
    _ref.read(currentApprovalProvider.notifier).state = null;
    _showingApproval = false;
    _updateDepthCount();

    Future.delayed(const Duration(milliseconds: 300), _processApprovalQueue);
  }

  /// Accept every file in the current batch.
  void acceptAllCurrent() {
    final current = _ref.read(currentApprovalProvider);
    if (current == null) return;
    resolveCurrent(List.filled(current.files.length, true));
  }

  /// Decline every file in the current batch.
  void declineAllCurrent() {
    final current = _ref.read(currentApprovalProvider);
    if (current == null) return;
    resolveCurrent(List.filled(current.files.length, false));
  }

  /// Whether a download slot is available. Called by upload handlers.
  bool canStartDownload(String transferId) {
    if (_activeDownloadIds.contains(transferId)) return true;
    if (_activeDownloadIds.length < maxParallelDownloads) {
      _activeDownloadIds.add(transferId);
      _approvedWaiting.remove(transferId);
      _ref.read(activeDownloadIdsProvider.notifier).state = Set.unmodifiable(
        _activeDownloadIds,
      );
      return true;
    }
    return false;
  }

  /// Wait until a download slot is available. Returns false if timed out.
  Future<bool> waitForDownloadSlot(
    String transferId, {
    Duration timeout = const Duration(seconds: 120),
  }) async {
    if (canStartDownload(transferId)) return true;

    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (canStartDownload(transferId)) return true;
    }

    _approvedWaiting.remove(transferId);
    return false;
  }

  /// Mark download as completed. Frees the slot for the next transfer.
  void downloadCompleted(String transferId, {required String senderAlias}) {
    _activeDownloadIds.remove(transferId);
    _ref.read(activeDownloadIdsProvider.notifier).state = Set.unmodifiable(
      _activeDownloadIds,
    );
    _approvedWaiting.remove(transferId);
  }

  /// Mark download as failed. Frees the slot.
  void downloadFailed(String transferId, {required String reason}) {
    debugPrint('Download $transferId failed: $reason');
    _activeDownloadIds.remove(transferId);
    _ref.read(activeDownloadIdsProvider.notifier).state = Set.unmodifiable(
      _activeDownloadIds,
    );
    _approvedWaiting.remove(transferId);
  }

  /// Pick the next batch from pending queue using round-robin per sender.
  void _processApprovalQueue() {
    if (_showingApproval) return;
    if (_pendingQueue.isEmpty) return;

    // Remove expired items
    _pendingQueue.removeWhere((q) {
      if (q.isExpired && !q.approvalCompleter.isCompleted) {
        q.approvalCompleter.complete(List.filled(q.files.length, false));
        return true;
      }
      return false;
    });

    if (_pendingQueue.isEmpty) {
      _updateDepthCount();
      return;
    }

    // Round-robin: pick from a sender we haven't served recently
    TransferBatch? next;
    for (final item in _pendingQueue) {
      if (!_recentSenders.contains(item.senderId)) {
        next = item;
        break;
      }
    }
    if (next == null) {
      _recentSenders.clear();
      next = _pendingQueue.first;
    }

    _recentSenders.add(next.senderId);
    if (_recentSenders.length > 20) _recentSenders.removeAt(0);

    _showingApproval = true;
    _ref.read(currentApprovalProvider.notifier).state = next;
    _updateDepthCount();
  }

  void _updateDepthCount() {
    final showing = _ref.read(currentApprovalProvider) != null;
    final count = showing ? _pendingQueue.length - 1 : _pendingQueue.length;
    _ref.read(queueDepthProvider.notifier).state = count.clamp(0, 999);
  }

  /// Total pending + approved-but-not-yet-downloaded items.
  int get totalPending {
    final pendingFiles = _pendingQueue.fold<int>(
      0,
      (sum, b) => sum + b.files.length,
    );
    return pendingFiles + _approvedWaiting.length;
  }

  /// Cancel a specific pending batch by ID (e.g. sender aborted before approval).
  void cancelBatch(String batchId) {
    TransferBatch? target;
    for (final b in _pendingQueue) {
      if (b.batchId == batchId) {
        target = b;
        break;
      }
    }
    if (target == null) return;

    if (!target.approvalCompleter.isCompleted) {
      target.approvalCompleter.complete(
        List.filled(target.files.length, false),
      );
    }
    _pendingQueue.removeWhere((q) => q.batchId == batchId);

    final current = _ref.read(currentApprovalProvider);
    if (current != null && current.batchId == batchId) {
      _ref.read(currentApprovalProvider.notifier).state = null;
      _showingApproval = false;
    }
    _updateDepthCount();
    _processApprovalQueue();
  }

  /// Auto-decline all pending batches from a specific sender (went offline).
  void declineAllFromSender(String senderId) {
    final toDecline = _pendingQueue
        .where((q) => q.senderId == senderId)
        .toList();
    for (final batch in toDecline) {
      if (!batch.approvalCompleter.isCompleted) {
        debugPrint('Auto-declining batch ${batch.batchId} — sender offline');
        batch.approvalCompleter.complete(
          List.filled(batch.files.length, false),
        );
      }
    }
    _pendingQueue.removeWhere((q) => q.senderId == senderId);

    final current = _ref.read(currentApprovalProvider);
    if (current != null && current.senderId == senderId) {
      _ref.read(currentApprovalProvider.notifier).state = null;
      _showingApproval = false;
    }

    _updateDepthCount();
    _processApprovalQueue();
  }
}
