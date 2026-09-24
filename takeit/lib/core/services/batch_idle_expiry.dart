import 'dart:async';

/// How long an approved batch may sit with no upload running before its
/// not-yet-uploaded sessions are dropped.
const kAcceptedBatchIdleTimeout = Duration(seconds: 120);

/// Expires approved-but-unused upload sessions per batch, counting only the
/// time the batch is idle.
///
/// Senders upload a batch's files one after another, so a fixed deadline
/// measured from approval would expire the later files while the earlier
/// ones are still streaming. Instead the countdown is paused while any upload
/// of the batch is running and restarts from zero when the last one ends.
class BatchIdleExpiry {
  final Duration idleTimeout;
  final void Function(String batchKey) onExpire;

  final Map<String, Timer> _timers = {};
  final Map<String, int> _activeUploads = {};

  BatchIdleExpiry({
    required this.onExpire,
    this.idleTimeout = kAcceptedBatchIdleTimeout,
  });

  /// Starts (or restarts) the idle countdown, unless an upload is running.
  void arm(String batchKey) {
    if ((_activeUploads[batchKey] ?? 0) > 0) return;
    _timers.remove(batchKey)?.cancel();
    _timers[batchKey] = Timer(idleTimeout, () {
      _timers.remove(batchKey);
      onExpire(batchKey);
    });
  }

  /// An upload for [batchKey] began — pause the countdown.
  void uploadStarted(String batchKey) {
    _activeUploads[batchKey] = (_activeUploads[batchKey] ?? 0) + 1;
    _timers.remove(batchKey)?.cancel();
  }

  /// An upload for [batchKey] finished (successfully or not) — once none are
  /// running, the countdown starts again for the files still waiting.
  void uploadEnded(String batchKey) {
    final remaining = (_activeUploads[batchKey] ?? 1) - 1;
    if (remaining > 0) {
      _activeUploads[batchKey] = remaining;
      return;
    }
    _activeUploads.remove(batchKey);
    arm(batchKey);
  }

  /// Stops tracking [batchKey] (all of its sessions are used up).
  void forget(String batchKey) {
    _timers.remove(batchKey)?.cancel();
    _activeUploads.remove(batchKey);
  }

  void dispose() {
    for (final t in _timers.values) {
      t.cancel();
    }
    _timers.clear();
    _activeUploads.clear();
  }
}
