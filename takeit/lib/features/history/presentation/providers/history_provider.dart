import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../data/services/history_storage.dart';
import '../../domain/entities/transfer_record.dart';

final historyProvider =
    StateNotifierProvider<HistoryNotifier, List<TransferRecord>>((ref) {
      return HistoryNotifier();
    });

/// Transfer history. The in-memory list is the source of truth and is
/// written out whole after every change.
///
/// Each change used to re-read the file, edit it and write it back, so
/// transfers finishing at the same time overwrote each other's records,
/// and records added before the initial load finished were wiped by it.
class HistoryNotifier extends StateNotifier<List<TransferRecord>> {
  static const maxRecords = 500;

  final HistoryStorage _storage;
  late final Future<void> _loaded;

  HistoryNotifier({HistoryStorage? storage})
    : _storage = storage ?? HistoryStorage(),
      super([]) {
    _loaded = _load();
  }

  /// Completes once the saved history has been loaded.
  Future<void> get ready => _loaded;

  Future<void> _load() async {
    final saved = await _storage.load();
    if (!mounted) return;
    // Keep anything recorded while the file was still loading (newest first).
    state = [...state, ...saved].take(maxRecords).toList();
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
    state = [record, ...state].take(maxRecords).toList();
    await _persist();
  }

  Future<void> clearHistory() async {
    state = [];
    await _loaded;
    await _storage.clear();
  }

  Future<void> deleteRecord(String id) async {
    state = state.where((r) => r.id != id).toList();
    await _persist();
  }

  /// Saves the current list — but only after the initial load, so an early
  /// save can't replace the stored history with a partial list.
  Future<void> _persist() async {
    await _loaded;
    if (!mounted) return;
    await _storage.save(state);
  }
}
