import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:takeit/features/transfer/data/services/file_transfer_service.dart';

void main() {
  late Directory dir;
  final service = FileTransferService();

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('takeit_part_test');
  });

  tearDown(() async {
    try {
      await dir.delete(recursive: true);
    } catch (_) {}
  });

  List<String> names() =>
      dir.listSync().map((e) => e.uri.pathSegments.last).toList()..sort();

  test('reserves <name>.part and finalizes to <name>', () async {
    final part = await service.reservePartFile(
      'photo.jpg',
      customDir: dir.path,
    );
    expect(names(), ['photo.jpg.part']);

    await File(part).writeAsString('data');
    final finalPath = await service.finalizePartFile(part);

    expect(finalPath, '${dir.path}/photo.jpg');
    expect(names(), ['photo.jpg']);
    expect(File(finalPath).readAsStringSync(), 'data');
  });

  test('skips names taken by finished files or other downloads', () async {
    File('${dir.path}/photo.jpg').writeAsStringSync('old');

    final first = await service.reservePartFile(
      'photo.jpg',
      customDir: dir.path,
    );
    final second = await service.reservePartFile(
      'photo.jpg',
      customDir: dir.path,
    );

    expect(first, '${dir.path}/photo_1.jpg.part');
    expect(second, '${dir.path}/photo_2.jpg.part');
  });

  test('concurrent reservations never share a file', () async {
    final parts = await Future.wait([
      for (var i = 0; i < 5; i++)
        service.reservePartFile('same.bin', customDir: dir.path),
    ]);
    expect(parts.toSet(), hasLength(5));
  });

  test(
    'finalizing picks the next free name if the target appeared meanwhile',
    () async {
      final part = await service.reservePartFile(
        'doc.pdf',
        customDir: dir.path,
      );
      await File(part).writeAsString('new');
      // e.g. the user saved another doc.pdf while this one was downloading.
      File('${dir.path}/doc.pdf').writeAsStringSync('someone else');

      final finalPath = await service.finalizePartFile(part);

      expect(finalPath, '${dir.path}/doc_1.pdf');
      expect(File('${dir.path}/doc.pdf').readAsStringSync(), 'someone else');
      expect(File(finalPath).readAsStringSync(), 'new');
    },
  );

  test('sender-supplied names are still sanitized', () async {
    final part = await service.reservePartFile(
      '../../evil.sh',
      customDir: dir.path,
    );
    expect(part, '${dir.path}/evil.sh.part');
  });
}
