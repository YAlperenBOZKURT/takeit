import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Session-scoped trusted devices (cleared on app restart). State is the set
/// of trusted fingerprints, for display.
final trustedDevicesProvider =
    StateNotifierProvider<TrustedDevicesNotifier, Set<String>>(
      (ref) => TrustedDevicesNotifier(),
    );

/// Session-scoped blocked devices (cleared on app restart). State is the set
/// of blocked fingerprints, for display.
final blockedDevicesProvider =
    StateNotifierProvider<BlockedDevicesNotifier, Set<String>>(
      (ref) => BlockedDevicesNotifier(),
    );

/// Trust is bound to the fingerprint *and* the IP the device had when the
/// user trusted it. Fingerprints are broadcast in every discovery
/// announcement, so on its own any device on the LAN could claim a trusted
/// one and have its files auto-accepted.
class TrustedDevicesNotifier extends StateNotifier<Set<String>> {
  TrustedDevicesNotifier() : super({});

  final Map<String, String> _ipOf = {};

  void add(String fingerprint, String ip) {
    _ipOf[fingerprint] = ip;
    state = {...state, fingerprint};
  }

  void remove(String fingerprint) {
    _ipOf.remove(fingerprint);
    state = {...state}..remove(fingerprint);
  }

  bool contains(String fingerprint) => state.contains(fingerprint);

  /// Whether a request claiming [fingerprint] and arriving from [ip] comes
  /// from the device the user trusted.
  bool isTrusted(String fingerprint, String? ip) =>
      ip != null && ip.isNotEmpty && _ipOf[fingerprint] == ip;
}

/// Blocks match the fingerprint *or* the IP the device had when blocked, so
/// simply announcing a new fingerprint doesn't get around a block.
class BlockedDevicesNotifier extends StateNotifier<Set<String>> {
  BlockedDevicesNotifier() : super({});

  final Map<String, String> _ipOf = {};

  void add(String fingerprint, String ip) {
    _ipOf[fingerprint] = ip;
    state = {...state, fingerprint};
  }

  void remove(String fingerprint) {
    _ipOf.remove(fingerprint);
    state = {...state}..remove(fingerprint);
  }

  bool contains(String fingerprint) => state.contains(fingerprint);

  bool isBlocked(String fingerprint, String? ip) =>
      state.contains(fingerprint) ||
      (ip != null && ip.isNotEmpty && _ipOf.containsValue(ip));
}
