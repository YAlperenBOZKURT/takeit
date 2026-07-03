import 'package:flutter/foundation.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'background_transfer_service.dart';

/// Keeps the device usable for transfers while any are active:
/// - wakelock on all platforms (mobile: screen stays on so the app stays
///   foreground — the only App Store-safe option on iOS; desktop: prevents
///   system sleep),
/// - plus the Android/iOS foreground service so Android also survives
///   backgrounding.
///
/// Each transfer feature reports its own activity under a source key; the
/// combined state drives the locks, so room and quick-send transfers can't
/// release each other's wakelock.
class TransferKeepAlive {
  TransferKeepAlive._();

  static final Map<String, bool> _activeSources = {};
  static bool _engaged = false;

  /// Clears all tracked state so tests start from a known-idle baseline.
  @visibleForTesting
  static void resetForTesting() {
    _activeSources.clear();
    _engaged = false;
  }

  /// Report whether [source] ('room', 'quick', …) currently has active
  /// transfers. Safe to call redundantly and from any transfer event.
  static void setActive(String source, bool active) {
    _activeSources[source] = active;
    final anyActive = _activeSources.values.any((a) => a);
    if (anyActive == _engaged) return;
    _engaged = anyActive;

    // Plugin failures (or test environments without plugins) must never
    // affect the transfer itself.
    if (anyActive) {
      WakelockPlus.enable().catchError((Object e) {
        debugPrint('TransferKeepAlive: wakelock enable failed: $e');
      });
      BackgroundTransferService.startIfNeeded().catchError((Object e) {
        debugPrint('TransferKeepAlive: foreground service failed: $e');
      });
    } else {
      WakelockPlus.disable().catchError((Object e) {
        debugPrint('TransferKeepAlive: wakelock disable failed: $e');
      });
      BackgroundTransferService.stop().catchError((Object e) {
        debugPrint('TransferKeepAlive: foreground service stop failed: $e');
      });
    }
  }
}
