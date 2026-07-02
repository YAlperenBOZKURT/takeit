import 'package:flutter_test/flutter_test.dart';
import 'package:takeit/features/discovery/data/models/device_model.dart';

void main() {
  group('DeviceModel JSON', () {
    final json = {
      'fingerprint': 'abc123',
      'alias': 'LazySloth',
      'deviceType': 'desktop',
      'ip': '192.168.1.5',
      'port': 53317,
      'os': 'windows',
    };

    test('round-trips through fromJson/toJson', () {
      final model = DeviceModel.fromJson(json);
      expect(model.fingerprint, 'abc123');
      expect(model.alias, 'LazySloth');
      expect(model.deviceType, 'desktop');
      expect(model.ip, '192.168.1.5');
      expect(model.port, 53317);
      expect(model.os, 'windows');
      expect(model.toJson(), json);
    });

    test('defaults os to empty string when absent', () {
      final partial = Map<String, dynamic>.from(json)..remove('os');
      final model = DeviceModel.fromJson(partial);
      expect(model.os, '');
    });

    test('toEntity carries fields and stamps lastSeen', () {
      final before = DateTime.now();
      final entity = DeviceModel.fromJson(json).toEntity();
      expect(entity.fingerprint, 'abc123');
      expect(entity.ip, '192.168.1.5');
      expect(entity.port, 53317);
      expect(
        entity.lastSeen.isAfter(before.subtract(const Duration(seconds: 1))),
        isTrue,
      );
    });
  });
}
