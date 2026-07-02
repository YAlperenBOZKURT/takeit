import 'package:flutter_test/flutter_test.dart';
import 'package:takeit/core/utils/format_utils.dart';

void main() {
  group('formatFileSize', () {
    test('formats bytes under 1 KB as B', () {
      expect(formatFileSize(0), '0 B');
      expect(formatFileSize(1), '1 B');
      expect(formatFileSize(1023), '1023 B');
    });

    test('formats KB with one decimal', () {
      expect(formatFileSize(1024), '1.0 KB');
      expect(formatFileSize(1536), '1.5 KB');
      expect(formatFileSize(1024 * 1024 - 1), '1024.0 KB');
    });

    test('formats MB with one decimal', () {
      expect(formatFileSize(1024 * 1024), '1.0 MB');
      expect(formatFileSize((1.5 * 1024 * 1024).round()), '1.5 MB');
    });

    test('formats GB with two decimals', () {
      expect(formatFileSize(1024 * 1024 * 1024), '1.00 GB');
      expect(formatFileSize((2.25 * 1024 * 1024 * 1024).round()), '2.25 GB');
    });

    test('boundary at exactly 1 KB switches unit', () {
      expect(formatFileSize(1023), endsWith(' B'));
      expect(formatFileSize(1024), endsWith(' KB'));
    });
  });
}
