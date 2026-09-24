import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:takeit/core/services/update_service.dart';

Map<String, dynamic> _release(String tag, List<String> assetNames) => {
  'tag_name': tag,
  'body': 'notes',
  'assets': [
    for (final name in assetNames)
      {'name': name, 'browser_download_url': 'https://dl.example/$name'},
  ],
};

String _apkName(String version) => 'TakeIt-$version.apk';

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

    test('ignores pre-release and build suffixes', () {
      expect(UpdateService.isNewer('1.0.3-beta.1', '1.0.2'), isTrue);
      expect(UpdateService.isNewer('1.0.2+7', '1.0.2'), isFalse);
      expect(UpdateService.isNewer('1.1.0', '1.0.9-rc1'), isTrue);
    });
  });

  group('UpdateService.parseRelease', () {
    test('picks this platform\'s asset and its checksum file', () {
      final info = UpdateService.parseRelease(
        _release('v1.2.0', [
          'TakeIt-1.2.0.apk',
          'TakeIt-1.2.0.apk.sha256',
          'TakeIt-Setup-1.2.0.exe',
        ]),
        currentVersion: '1.1.0',
        assetNameFor: _apkName,
      )!;

      expect(info.version, '1.2.0');
      expect(info.downloadUrl, 'https://dl.example/TakeIt-1.2.0.apk');
      expect(info.checksumUrl, 'https://dl.example/TakeIt-1.2.0.apk.sha256');
    });

    test('a release without checksums still yields an update', () {
      final info = UpdateService.parseRelease(
        _release('v1.2.0', ['TakeIt-1.2.0.apk']),
        currentVersion: '1.1.0',
        assetNameFor: _apkName,
      );
      expect(info, isNotNull);
      expect(info!.checksumUrl, isNull);
    });

    test('returns null when not newer or no asset for this platform', () {
      expect(
        UpdateService.parseRelease(
          _release('v1.1.0', ['TakeIt-1.1.0.apk']),
          currentVersion: '1.1.0',
          assetNameFor: _apkName,
        ),
        isNull,
      );
      expect(
        UpdateService.parseRelease(
          _release('v1.2.0', ['TakeIt-Setup-1.2.0.exe']),
          currentVersion: '1.1.0',
          assetNameFor: _apkName,
        ),
        isNull,
      );
    });
  });

  group('checksum verification', () {
    // sha256("hello\n")
    const helloDigest =
        '5891b5b522d5df086d0ff0b110fbd9d21bb4fc7163af34d08286a2e846f6be03';

    test('parses sha256sum output', () {
      expect(
        UpdateService.parseChecksumFile(
          '${helloDigest.toUpperCase()}  TakeIt-1.2.0.apk\n',
        ),
        helloDigest,
      );
      expect(UpdateService.parseChecksumFile('not a checksum'), isNull);
    });

    test(
      'matches a file with the right digest and rejects a changed one',
      () async {
        final dir = await Directory.systemTemp.createTemp('takeit_sha_test');
        addTearDown(() => dir.delete(recursive: true));
        final file = File('${dir.path}/installer.bin');

        await file.writeAsString('hello\n');
        expect(
          await UpdateService.fileMatchesSha256(file.path, helloDigest),
          isTrue,
        );

        await file.writeAsString('hellO\n');
        expect(
          await UpdateService.fileMatchesSha256(file.path, helloDigest),
          isFalse,
        );
      },
    );
  });
}
