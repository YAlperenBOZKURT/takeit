import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:takeit/features/history/data/services/history_storage.dart';
import 'package:takeit/features/history/presentation/providers/history_provider.dart';

void main() {
  late Directory dir;
  late File file;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('takeit_history_test');
    file = File('${dir.path}/transfer_history.json');
  });

  tearDown(() async {
    try {
      await dir.delete(recursive: true);
    } catch (_) {}
  });

  List<String> namesOnDisk() => [
    for (final r in jsonDecode(file.readAsStringSync()) as List)
      (r as Map<String, dynamic>)['fileName'] as String,
  ];

  Future<void> add(HistoryNotifier n, String name) => n.addRecord(
    fileName: name,
    fileSize: 1,
    peerAlias: 'peer',
    direction: 'received',
  );

  test('records finishing at the same time are all persisted', () async {
    final notifier = HistoryNotifier(storage: HistoryStorage(file: file));
    await notifier.ready;

    await Future.wait([for (var i = 0; i < 10; i++) add(notifier, 'f$i')]);

    expect(namesOnDisk(), hasLength(10));
    expect(namesOnDisk().toSet(), {for (var i = 0; i < 10; i++) 'f$i'});
    notifier.dispose();
  });

  test('a record added before the saved history loaded is kept', () async {
    final first = HistoryNotifier(storage: HistoryStorage(file: file));
    await first.ready;
    await add(first, 'old');
    first.dispose();

    final second = HistoryNotifier(storage: HistoryStorage(file: file));
    await add(second, 'new'); // before awaiting ready

    expect(second.state.map((r) => r.fileName), ['new', 'old']);
    expect(namesOnDisk(), ['new', 'old']);
    second.dispose();
  });

  test('history is capped at maxRecords', () async {
    final notifier = HistoryNotifier(storage: HistoryStorage(file: file));
    await notifier.ready;

    for (var i = 0; i < HistoryNotifier.maxRecords + 5; i++) {
      await add(notifier, 'f$i');
    }

    expect(notifier.state, hasLength(HistoryNotifier.maxRecords));
    expect(namesOnDisk(), hasLength(HistoryNotifier.maxRecords));
    expect(notifier.state.first.fileName, 'f${HistoryNotifier.maxRecords + 4}');
    notifier.dispose();
  });

  test('clear removes the stored history', () async {
    final notifier = HistoryNotifier(storage: HistoryStorage(file: file));
    await add(notifier, 'x');

    await notifier.clearHistory();

    expect(notifier.state, isEmpty);
    expect(file.existsSync(), isFalse);
    notifier.dispose();
  });
}
