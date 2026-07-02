import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Session-scoped trusted device fingerprints (cleared on app restart).
final trustedDevicesProvider =
    StateNotifierProvider<_FingerprintSetNotifier, Set<String>>(
      (ref) => _FingerprintSetNotifier(),
    );

/// Session-scoped blocked device fingerprints (cleared on app restart).
final blockedDevicesProvider =
    StateNotifierProvider<_FingerprintSetNotifier, Set<String>>(
      (ref) => _FingerprintSetNotifier(),
    );

class _FingerprintSetNotifier extends StateNotifier<Set<String>> {
  _FingerprintSetNotifier() : super({});

  void add(String fingerprint) => state = {...state, fingerprint};

  void remove(String fingerprint) => state = {...state}..remove(fingerprint);

  bool contains(String fingerprint) => state.contains(fingerprint);
}
