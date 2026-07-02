import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../../domain/entities/transfer_record.dart';

class HistoryStorage {
  static const _fileName = 'transfer_history.json';
  File? _file;

  Future<File> _getFile() async {
    if (_file != null) return _file!;
    final dir = await getApplicationSupportDirectory();
    _file = File('${dir.path}/$_fileName');
    return _file!;
  }

  Future<List<TransferRecord>> load() async {
    try {
      final file = await _getFile();
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

  Future<void> save(List<TransferRecord> records) async {
    final file = await _getFile();
    final json = jsonEncode(records.map((r) => r.toJson()).toList());
    await file.writeAsString(json);
  }

  Future<void> addRecord(TransferRecord record) async {
    final records = await load();
    records.insert(0, record);
    if (records.length > 500) {
      records.removeRange(500, records.length);
    }
    await save(records);
  }

  Future<void> clear() async {
    final file = await _getFile();
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<void> deleteRecord(String id) async {
    final records = await load();
    records.removeWhere((r) => r.id == id);
    await save(records);
  }
}
