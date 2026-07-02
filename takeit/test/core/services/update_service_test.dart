import 'package:flutter_test/flutter_test.dart';
import 'package:takeit/core/services/update_service.dart';

void main() {
  group('UpdateService.isNewer', () {
    test('detects a newer patch version', () {
      expect(UpdateService.isNewer('1.0.1', '1.0.0'), isTrue);
    });

    test('detects a newer minor version', () {
      expect(UpdateService.isNewer('1.1.0', '1.0.9'), isTrue);
    });

    test('detects a newer major version', () {
      expect(UpdateService.isNewer('2.0.0', '1.9.9'), isTrue);
    });

    test('returns false for equal versions', () {
      expect(UpdateService.isNewer('1.0.0', '1.0.0'), isFalse);
    });

    test('returns false for older versions', () {
      expect(UpdateService.isNewer('1.0.0', '1.0.1'), isFalse);
      expect(UpdateService.isNewer('1.0.0', '2.0.0'), isFalse);
    });

    test('compares numerically, not lexically (10 > 2)', () {
      expect(UpdateService.isNewer('1.0.10', '1.0.2'), isTrue);
      expect(UpdateService.isNewer('1.0.2', '1.0.10'), isFalse);
    });

    test('treats missing components as 0', () {
      expect(UpdateService.isNewer('1.1', '1.0.0'), isTrue);
      expect(UpdateService.isNewer('1', '1.0.0'), isFalse);
    });

    test('tolerates non-numeric junk by treating it as 0', () {
      expect(UpdateService.isNewer('1.0.x', '1.0.0'), isFalse);
    });
  });
}
