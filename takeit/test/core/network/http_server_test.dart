import 'package:flutter_test/flutter_test.dart';
import 'package:takeit/core/network/http_server.dart';

void main() {
  group('AppHttpServer.isPrivateIp', () {
    test('allows the 10.0.0.0/8 range', () {
      expect(AppHttpServer.isPrivateIp('10.0.0.1'), isTrue);
      expect(AppHttpServer.isPrivateIp('10.255.255.255'), isTrue);
    });

    test('allows the 192.168.0.0/16 range', () {
      expect(AppHttpServer.isPrivateIp('192.168.1.42'), isTrue);
    });

    test('allows the 172.16.0.0 – 172.31.255.255 range only', () {
      expect(AppHttpServer.isPrivateIp('172.16.0.1'), isTrue);
      expect(AppHttpServer.isPrivateIp('172.31.255.255'), isTrue);
      // Outside the private block.
      expect(AppHttpServer.isPrivateIp('172.15.0.1'), isFalse);
      expect(AppHttpServer.isPrivateIp('172.32.0.1'), isFalse);
    });

    test('allows loopback and link-local', () {
      expect(AppHttpServer.isPrivateIp('127.0.0.1'), isTrue);
      expect(AppHttpServer.isPrivateIp('169.254.1.1'), isTrue);
    });

    test('blocks public IPs', () {
      expect(AppHttpServer.isPrivateIp('8.8.8.8'), isFalse);
      expect(AppHttpServer.isPrivateIp('1.1.1.1'), isFalse);
      expect(AppHttpServer.isPrivateIp('93.184.216.34'), isFalse);
    });

    test('rejects empty/unknown origin (fail-closed)', () {
      expect(AppHttpServer.isPrivateIp(''), isFalse);
    });

    test('rejects non-IPv4 / unparseable strings (fail-closed)', () {
      expect(AppHttpServer.isPrivateIp('::1'), isFalse);
      expect(AppHttpServer.isPrivateIp('not-an-ip'), isFalse);
      expect(AppHttpServer.isPrivateIp('10.0.0'), isFalse);
      expect(AppHttpServer.isPrivateIp('192.168.x.1'), isFalse);
    });
  });
}
