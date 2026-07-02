import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../data/services/history_storage.dart';
import '../../domain/entities/transfer_record.dart';

final historyProvider =
    StateNotifierProvider<HistoryNotifier, List<TransferRecord>>((ref) {
      return HistoryNotifier();
    });

class HistoryNotifier extends StateNotifier<List<TransferRecord>> {
  final HistoryStorage _storage = HistoryStorage();

  HistoryNotifier() : super([]) {
    _load();
  }

  Future<void> _load() async {
    state = await _storage.load();
  }

  Future<void> addRecord({
    required String fileName,
    required int fileSize,
    required String peerAlias,
    required String direction,
    String? fileMimeType,
    String? savePath,
  }) async {
    final record = TransferRecord(
      id: const Uuid().v4(),
      fileName: fileName,
      fileSize: fileSize,
      peerAlias: peerAlias,
      direction: direction,
      timestamp: DateTime.now(),
      fileMimeType: fileMimeType,
      savePath: savePath,
    );
    await _storage.addRecord(record);
    state = [record, ...state];
    if (state.length > 500) {
      state = state.sublist(0, 500);
    }
  }

  Future<void> clearHistory() async {
    await _storage.clear();
    state = [];
  }

  Future<void> deleteRecord(String id) async {
    await _storage.deleteRecord(id);
    state = state.where((r) => r.id != id).toList();
  }
}
