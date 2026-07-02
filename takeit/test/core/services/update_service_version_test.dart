import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:takeit/core/services/update_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UpdateService.currentVersion', () {
    test('reads the version from package info (the single source)', () async {
      PackageInfo.setMockInitialValues(
        appName: 'takeit',
        packageName: 'com.takeit.app',
        version: '1.0.4',
        buildNumber: '4',
        buildSignature: '',
      );

      expect(await UpdateService.currentVersion(), '1.0.4');
    });
  });
}
