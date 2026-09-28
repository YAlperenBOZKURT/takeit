import 'package:flutter_test/flutter_test.dart';
import 'package:takeit/features/discovery/presentation/providers/device_actions_provider.dart';

void main() {
  group('TrustedDevicesNotifier', () {
    test('trusts the device only at the IP it was trusted from', () {
      final trusted = TrustedDevicesNotifier()..add('fp-a', '192.168.1.10');

      expect(trusted.isTrusted('fp-a', '192.168.1.10'), isTrue);
      // Same (publicly broadcast) fingerprint from another device.
      expect(trusted.isTrusted('fp-a', '192.168.1.66'), isFalse);
      expect(trusted.isTrusted('fp-a', null), isFalse);
      expect(trusted.isTrusted('fp-a', ''), isFalse);
      expect(trusted.isTrusted('fp-b', '192.168.1.10'), isFalse);
    });

    test('remove drops the trust', () {
      final trusted = TrustedDevicesNotifier()..add('fp-a', '192.168.1.10');
      trusted.remove('fp-a');
      expect(trusted.isTrusted('fp-a', '192.168.1.10'), isFalse);
      expect(trusted.state, isEmpty);
    });
  });

  group('BlockedDevicesNotifier', () {
    test('blocks by fingerprint or by IP', () {
      final blocked = BlockedDevicesNotifier()..add('fp-a', '192.168.1.10');

      expect(blocked.isBlocked('fp-a', '192.168.1.99'), isTrue);
      // A fresh fingerprint from the blocked device's address.
      expect(blocked.isBlocked('fp-new', '192.168.1.10'), isTrue);
      expect(blocked.isBlocked('fp-other', '192.168.1.11'), isFalse);
      expect(blocked.isBlocked('fp-other', ''), isFalse);
    });

    test('unblocking clears both', () {
      final blocked = BlockedDevicesNotifier()..add('fp-a', '192.168.1.10');
      blocked.remove('fp-a');
      expect(blocked.isBlocked('fp-a', '192.168.1.10'), isFalse);
      expect(blocked.isBlocked('fp-new', '192.168.1.10'), isFalse);
    });
  });
}
