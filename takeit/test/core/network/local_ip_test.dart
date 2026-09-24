import 'package:flutter_test/flutter_test.dart';
import 'package:takeit/core/network/local_ip.dart';

void main() {
  group('isVirtualInterfaceName', () {
    test('flags Windows virtual/VPN adapters by their friendly names', () {
      for (final name in [
        'vethernet (wsl)',
        'vethernet (default switch)',
        'virtualbox host-only network',
        'vmware network adapter vmnet8',
        'hyper-v virtual ethernet adapter',
        'zerotier one [8056c2e21c000001]',
        'openvpn tap-windows6',
        'tailscale',
      ]) {
        expect(isVirtualInterfaceName(name), isTrue, reason: name);
      }
    });

    test('flags Linux/macOS container and VPN interfaces', () {
      for (final name in [
        'docker0',
        'br-1a2b3c',
        'virbr0',
        'vboxnet0',
        'wg0',
        'utun3',
      ]) {
        expect(isVirtualInterfaceName(name), isTrue, reason: name);
      }
    });

    test('keeps real LAN adapters', () {
      for (final name in [
        'wi-fi',
        'ethernet',
        'ethernet 2',
        'wlan0',
        'eth0',
        'en0',
      ]) {
        expect(isVirtualInterfaceName(name), isFalse, reason: name);
      }
    });
  });
}
