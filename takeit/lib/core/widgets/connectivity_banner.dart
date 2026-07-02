import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../l10n/app_strings.dart';

/// Periodically checks network interfaces and shows a banner when disconnected.
class ConnectivityBanner extends StatefulWidget {
  const ConnectivityBanner({super.key});

  @override
  State<ConnectivityBanner> createState() => _ConnectivityBannerState();
}

class _ConnectivityBannerState extends State<ConnectivityBanner> {
  bool _connected = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _check();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _check());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _check() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
      );
      final hasNetwork = interfaces.any(
        (iface) => iface.addresses.any((addr) => !addr.isLoopback),
      );
      if (mounted && hasNetwork != _connected) {
        setState(() => _connected = hasNetwork);
      }
    } catch (_) {
      if (mounted && _connected) {
        setState(() => _connected = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_connected) return const SizedBox.shrink();
    final s = AppStrings.of(context);
    final theme = Theme.of(context);

    return MaterialBanner(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      content: Row(
        children: [
          const Icon(Icons.wifi_off, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Text(
            s.noConnection,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
      backgroundColor: theme.colorScheme.error,
      actions: const [SizedBox.shrink()],
    );
  }
}
