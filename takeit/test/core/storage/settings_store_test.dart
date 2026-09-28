import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:takeit/core/storage/settings_store.dart';

void main() {
  late Directory dir;
  late File file;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('takeit_settings_test');
    file = File('${dir.path}/settings.json');
  });

  tearDown(() async {
    try {
      await dir.delete(recursive: true);
    } catch (_) {}
  });

  Map<String, dynamic> onDisk() =>
      jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;

  test('values survive a reload', () async {
    final store = await SettingsStore.load(file);
    await store.set('nickname', 'LazySloth');
    await store.set('notificationSound', false);

    final reloaded = await SettingsStore.load(file);
    expect(reloaded.get<String>('nickname'), 'LazySloth');
    expect(reloaded.get<bool>('notificationSound'), isFalse);
  });

  test('concurrent saves of different keys keep every key', () async {
    final store = await SettingsStore.load(file);
    await store.set('fingerprint', 'fp-1');

    await Future.wait([
      store.set('themeMode', 'dark'),
      store.set('language', 'tr'),
      store.set('nickname', 'A'),
      store.set('downloadPath', '/tmp/x'),
    ]);

    expect(onDisk(), {
      'fingerprint': 'fp-1',
      'themeMode': 'dark',
      'language': 'tr',
      'nickname': 'A',
      'downloadPath': '/tmp/x',
    });
    expect(File('${file.path}.tmp').existsSync(), isFalse);
  });

  test('setting null removes the key', () async {
    final store = await SettingsStore.load(file);
    await store.set('downloadPath', '/tmp/x');
    await store.set('downloadPath', null);
    expect(onDisk().containsKey('downloadPath'), isFalse);
  });

  test('get returns null for a value of the wrong type', () async {
    file.writeAsStringSync(jsonEncode({'notificationSound': 'yes'}));
    final store = await SettingsStore.load(file);
    expect(store.get<bool>('notificationSound'), isNull);
  });

  test(
    'a corrupt file is kept aside instead of silently overwritten',
    () async {
      file.writeAsStringSync('{"fingerprint": "fp-1", "nick');

      final store = await SettingsStore.load(file);

      expect(store.get<String>('fingerprint'), isNull);
      expect(
        File('${file.path}.corrupt').readAsStringSync(),
        '{"fingerprint": "fp-1", "nick',
      );
    },
  );

  test('in-memory store never touches disk', () async {
    final store = SettingsStore.inMemory({'a': 1});
    await store.set('b', 2);
    expect(store.get<int>('a'), 1);
    expect(store.get<int>('b'), 2);
    expect(file.existsSync(), isFalse);
  });
}
