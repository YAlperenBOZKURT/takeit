import 'package:flutter_test/flutter_test.dart';
import 'package:takeit/core/constants/network_constants.dart';
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

    test('toJson tags the payload with the TakeIt protocol id', () {
      const msg = MulticastMessage(
        alias: 'A',
        deviceType: 'desktop',
        fingerprint: 'fp-4',
        port: 53317,
        announce: true,
        ip: '',
      );
      expect(msg.toJson()['protocol'], kProtocolId);
      expect(MulticastMessage.isTakeIt(msg.toJson()), isTrue);
    });
  });

  group('MulticastMessage.isTakeIt', () {
    test('rejects a LocalSend announcement on the shared group/port', () {
      // Shape of a LocalSend v2 multicast announcement — it would otherwise
      // parse cleanly as a TakeIt device.
      final localSend = {
        'alias': 'Nice Orange',
        'version': '2.1',
        'deviceModel': 'Samsung',
        'deviceType': 'mobile',
        'fingerprint': 'random-string',
        'port': 53317,
        'protocol': 'https',
        'download': true,
        'announce': true,
      };
      expect(MulticastMessage.isTakeIt(localSend), isFalse);
      expect(
        MulticastMessage.isTakeIt({...localSend, 'protocol': 'http'}),
        isFalse,
      );
    });

    test('accepts announcements from builds without the protocol field', () {
      expect(
        MulticastMessage.isTakeIt({
          'alias': 'OldTakeIt',
          'deviceType': 'desktop',
          'fingerprint': 'fp-old',
          'port': 53317,
        }),
        isTrue,
      );
    });
  });
}
