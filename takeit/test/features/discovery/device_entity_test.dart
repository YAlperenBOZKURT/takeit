import 'package:flutter_test/flutter_test.dart';
import 'package:takeit/features/discovery/domain/entities/device.dart';

void main() {
  group('Device entity', () {
    final seen = DateTime.parse('2026-06-30T10:00:00.000');

    Device device() => Device(
      fingerprint: 'fp',
      alias: 'LazySloth',
      deviceType: 'desktop',
      ip: '192.168.1.5',
      port: 53317,
      lastSeen: seen,
    );

    test('value equality holds for identical fields', () {
      expect(device(), device());
    });

    test('os defaults to empty string', () {
      expect(device().os, '');
    });

    test('copyWith changes only the requested field', () {
      final updated = device().copyWith(alias: 'GrumpyPenguin');
      expect(updated.alias, 'GrumpyPenguin');
      expect(updated.fingerprint, 'fp');
      expect(updated.ip, '192.168.1.5');
      expect(updated, isNot(device()));
    });
  });
}
