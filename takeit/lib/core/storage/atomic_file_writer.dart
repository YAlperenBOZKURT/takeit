import 'dart:io';
import 'package:flutter/foundation.dart';

/// Writes a file so that it is never seen half-written, one write at a time.
///
/// Each write goes to `<path>.tmp` first and is then renamed over the real
/// file, so a crash or power loss mid-write leaves the previous version
/// intact instead of a truncated file. Writes are queued: a later write
/// never runs concurrently with — or gets overtaken by — an earlier one.
class AtomicFileWriter {
  final File file;
  Future<void> _queue = Future.value();

  AtomicFileWriter(this.file);

  /// Queues [contents] to be written. Completes when this write (and every
  /// write queued before it) has finished; errors are logged, not thrown,
  /// so one failed write doesn't poison the queue.
  Future<void> write(String contents) {
    _queue = _queue.then((_) => _writeNow(contents)).catchError((Object e) {
      debugPrint('Failed to write ${file.path}: $e');
    });
    return _queue;
  }

  /// Queues deleting the file (after any pending writes).
  Future<void> delete() {
    _queue = _queue
        .then((_) async {
          if (await file.exists()) await file.delete();
        })
        .catchError((Object e) {
          debugPrint('Failed to delete ${file.path}: $e');
        });
    return _queue;
  }

  Future<void> _writeNow(String contents) async {
    await file.parent.create(recursive: true);
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(contents, flush: true);
    await tmp.rename(file.path);
  }
}
