import 'package:flutter_test/flutter_test.dart';
import 'package:takeit/core/network/multicast_service.dart';

void main() {
  group('MulticastMessage', () {
    test('fromJson takes ip from the source address, not the payload', () {
      final msg = MulticastMessage.fromJson({
        'alias': 'LazySloth',
        'deviceType': 'mobile',
        'fingerprint': 'fp-1',
        'port': 53317,
        'announce': true,
      }, '192.168.1.99');

      expect(msg.ip, '192.168.1.99');
      expect(msg.alias, 'LazySloth');
      expect(msg.announce, isTrue);
      expect(msg.os, '');
    });

    test('announce defaults to false when missing', () {
      final msg = MulticastMessage.fromJson({
        'alias': 'A',
        'deviceType': 'desktop',
        'fingerprint': 'fp-2',
        'port': 1,
      }, '10.0.0.1');
      expect(msg.announce, isFalse);
    });

    test('toJson does not leak ip (receiver derives it from source)', () {
      const msg = MulticastMessage(
        alias: 'A',
        deviceType: 'desktop',
        fingerprint: 'fp-3',
        port: 53317,
        announce: false,
        ip: '192.168.1.5',
        os: 'linux',
      );
      final json = msg.toJson();
      expect(json.containsKey('ip'), isFalse);
      expect(json['fingerprint'], 'fp-3');
      expect(json['os'], 'linux');
    });
  });
}
