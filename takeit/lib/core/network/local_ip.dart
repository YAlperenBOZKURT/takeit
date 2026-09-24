import 'dart:io';
import 'package:flutter/foundation.dart';

/// Picks the best local IPv4 address, optionally preferring the subnet of [preferredPeerIp].
/// Falls back to 127.0.0.1 if none found.
Future<String> resolveLocalIp({String? preferredPeerIp}) async {
  final candidates = await _listCandidates();
  if (candidates.isEmpty) return '127.0.0.1';

  if (preferredPeerIp != null && preferredPeerIp.isNotEmpty) {
    final peerSubnet = _subnetPrefix(preferredPeerIp);
    final sameSubnet = candidates
        .where((c) => _subnetPrefix(c.ip) == peerSubnet)
        .toList();
    if (sameSubnet.isNotEmpty) {
      return _bestOf(sameSubnet);
    }
  }
  return _bestOf(candidates);
}

/// Returns all non-loopback, non-virtual, non-link-local IPv4 addresses.
/// Best-effort; safe to call from UI.
Future<List<String>> listUsableLocalIps() async {
  final candidates = await _listCandidates();
  final filtered = candidates
      .where((c) => !isVirtualInterfaceName(c.ifaceName) && !_isLinkLocal(c.ip))
      .map((c) => c.ip)
      .toSet()
      .toList();
  if (filtered.isNotEmpty) return filtered;
  // Fallback: at least give *something* if filters wiped everything.
  return candidates.map((c) => c.ip).toSet().toList();
}

Future<List<({String ip, String ifaceName})>> _listCandidates() async {
  try {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
    );
    final out = <({String ip, String ifaceName})>[];
    for (final iface in interfaces) {
      final ifaceName = iface.name.toLowerCase();
      for (final addr in iface.addresses) {
        if (!addr.isLoopback) {
          out.add((ip: addr.address, ifaceName: ifaceName));
        }
      }
    }
    return out;
  } catch (_) {
    return const [];
  }
}

String _bestOf(List<({String ip, String ifaceName})> cs) {
  final nonVirtual = cs
      .where((c) => !isVirtualInterfaceName(c.ifaceName))
      .toList();
  final nonLinkLocal = nonVirtual.where((c) => !_isLinkLocal(c.ip)).toList();
  if (nonLinkLocal.isNotEmpty) return nonLinkLocal.first.ip;
  if (nonVirtual.isNotEmpty) return nonVirtual.first.ip;
  final nonLinkLocalAny = cs.where((c) => !_isLinkLocal(c.ip)).toList();
  if (nonLinkLocalAny.isNotEmpty) return nonLinkLocalAny.first.ip;
  return cs.first.ip;
}

String _subnetPrefix(String ip) {
  final p = ip.split('.');
  if (p.length != 4) return ip;
  return '${p[0]}.${p[1]}.${p[2]}';
}

/// Whether [ifaceName] (lower-cased) belongs to a virtual, container or VPN
/// adapter rather than the LAN. Covers Linux/macOS device names and the
/// friendly names Windows reports (e.g. "vEthernet (WSL)").
@visibleForTesting
bool isVirtualInterfaceName(String ifaceName) {
  const prefixes = [
    'docker',
    'br-',
    'virbr',
    'vboxnet',
    'vmnet',
    'zt',
    'tailscale',
    'wg',
    'utun',
    'vethernet',
  ];
  const fragments = [
    'virtualbox',
    'vmware',
    'hyper-v',
    'zerotier',
    'wireguard',
    'tap-windows',
  ];
  return prefixes.any(ifaceName.startsWith) ||
      fragments.any(ifaceName.contains);
}

bool _isLinkLocal(String ip) => ip.startsWith('169.254.');
