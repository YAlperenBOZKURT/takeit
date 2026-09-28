import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../../../../core/storage/atomic_file_writer.dart';
import '../../domain/entities/transfer_record.dart';

class HistoryStorage {
  static const _fileName = 'transfer_history.json';

  /// Fixed file for tests; otherwise resolved from path_provider.
  final File? _fixedFile;
  AtomicFileWriter? _writer;

  HistoryStorage({File? file}) : _fixedFile = file;

  Future<AtomicFileWriter> _getWriter() async {
    if (_writer != null) return _writer!;
    final file =
        _fixedFile ??
        File('${(await getApplicationSupportDirectory()).path}/$_fileName');
    return _writer = AtomicFileWriter(file);
  }

  Future<List<TransferRecord>> load() async {
    try {
      final file = (await _getWriter()).file;
      if (!await file.exists()) return [];
      final content = await file.readAsString();
      final list = jsonDecode(content) as List;
      return list
          .map((e) => TransferRecord.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Replaces the stored history with [records] (atomic, queued).
  Future<void> save(List<TransferRecord> records) async {
    final json = jsonEncode(records.map((r) => r.toJson()).toList());
    try {
      await (await _getWriter()).write(json);
    } catch (_) {
      // No storage available (e.g. tests without plugins) — keep in memory.
    }
  }

  Future<void> clear() async {
    try {
      await (await _getWriter()).delete();
    } catch (_) {}
  }
}
