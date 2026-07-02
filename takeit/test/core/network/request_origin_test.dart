import 'package:flutter_test/flutter_test.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:takeit/core/network/request_origin.dart';

shelf.Request _req({String? realIp}) {
  return shelf.Request(
    'POST',
    Uri.parse('http://localhost/api/takeit/v1/message'),
    headers: realIp == null ? const {} : {'x-real-ip': realIp},
  );
}

void main() {
  group('remoteIpOf', () {
    test('returns the X-Real-IP header value', () {
      expect(remoteIpOf(_req(realIp: '192.168.1.5')), '192.168.1.5');
    });

    test('is case-insensitive on the header name', () {
      final req = shelf.Request(
        'POST',
        Uri.parse('http://localhost/x'),
        headers: {'X-Real-IP': '10.0.0.9'},
      );
      expect(remoteIpOf(req), '10.0.0.9');
    });

    test('returns null when header is absent', () {
      expect(remoteIpOf(_req()), isNull);
    });
  });

  group('isFromAllowedIp', () {
    const members = ['192.168.1.5', '192.168.1.6'];

    test('accepts an IP in the allow-list', () {
      expect(isFromAllowedIp(_req(realIp: '192.168.1.6'), members), isTrue);
    });

    test('rejects an IP not in the allow-list', () {
      expect(isFromAllowedIp(_req(realIp: '192.168.1.99'), members), isFalse);
    });

    test('rejects when origin IP is unknown (fail-closed)', () {
      expect(isFromAllowedIp(_req(), members), isFalse);
    });

    test('rejects against an empty member list', () {
      expect(isFromAllowedIp(_req(realIp: '192.168.1.5'), const []), isFalse);
    });
  });
}
