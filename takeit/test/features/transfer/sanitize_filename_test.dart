import 'package:flutter_test/flutter_test.dart';
import 'package:takeit/features/transfer/data/services/file_transfer_service.dart';

void main() {
  group('FileTransferService.sanitizeFileName', () {
    test('keeps a normal filename unchanged', () {
      expect(FileTransferService.sanitizeFileName('photo.jpg'), 'photo.jpg');
    });

    test('strips directory components (keeps basename only)', () {
      expect(
        FileTransferService.sanitizeFileName('../../etc/passwd'),
        'passwd',
      );
      expect(
        FileTransferService.sanitizeFileName(r'..\..\Windows\notes.txt'),
        'notes.txt',
      );
    });

    test('never lets path separators or .. through', () {
      const attacks = [
        '../../../../etc/shadow',
        r'..\..\..\boot.ini',
        'foo/../bar.txt',
        '....//....//x',
      ];
      for (final a in attacks) {
        final result = FileTransferService.sanitizeFileName(a);
        expect(result.contains('/'), isFalse, reason: 'no slash in "$result"');
        expect(
          result.contains(r'\'),
          isFalse,
          reason: 'no backslash in "$result"',
        );
        expect(result.contains('..'), isFalse, reason: 'no .. in "$result"');
      }
    });

    test('replaces illegal characters', () {
      final result = FileTransferService.sanitizeFileName('a<b>c:d"e|f?g*.txt');
      expect(result, isNot(matches(RegExp(r'[<>:"|?*]'))));
    });

    test('prefixes Windows reserved device names', () {
      expect(FileTransferService.sanitizeFileName('CON'), '_CON');
      expect(FileTransferService.sanitizeFileName('con.txt'), '_con.txt');
      expect(FileTransferService.sanitizeFileName('NUL.log'), '_NUL.log');
      expect(FileTransferService.sanitizeFileName('COM1'), '_COM1');
    });

    test('does not flag non-reserved names that merely contain them', () {
      expect(
        FileTransferService.sanitizeFileName('CONTRACT.pdf'),
        'CONTRACT.pdf',
      );
    });

    test('falls back to "file" for empty/dot-only names', () {
      expect(FileTransferService.sanitizeFileName(''), 'file');
      expect(FileTransferService.sanitizeFileName('.'), 'file');
      expect(FileTransferService.sanitizeFileName('   '), 'file');
    });
  });
}
