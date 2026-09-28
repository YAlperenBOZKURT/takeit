import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'atomic_file_writer.dart';

/// App settings, loaded once at start-up. main() overrides this with the
/// store backed by settings.json; the default is in-memory (tests).
final settingsStoreProvider = Provider<SettingsStore>(
  (ref) => SettingsStore.inMemory(),
);

/// Single owner of settings.json.
///
/// Every setting used to read-modify-write the file on its own, so two
/// saves at once could drop each other's keys, and a file corrupted by a
/// crash mid-write was silently replaced by `{}` — losing the device
/// fingerprint too. Now the values live in memory, reads are synchronous,
/// and each change rewrites the whole map atomically through one queue.
class SettingsStore {
  final AtomicFileWriter? _writer;
  final Map<String, dynamic> _values;

  SettingsStore._(this._writer, this._values);

  /// Store that never touches disk.
  SettingsStore.inMemory([Map<String, dynamic>? values])
    : this._(null, {...?values});

  /// Loads settings.json from the app support directory.
  static Future<SettingsStore> open() async {
    final dir = await getApplicationSupportDirectory();
    return load(File('${dir.path}/settings.json'));
  }

  /// Loads [file]. A missing file means no settings yet; an unreadable one
  /// is kept aside as `<name>.corrupt` (rather than silently overwritten)
  /// and the app starts from defaults.
  @visibleForTesting
  static Future<SettingsStore> load(File file) async {
    var values = <String, dynamic>{};
    try {
      if (await file.exists()) {
        final decoded = jsonDecode(await file.readAsString());
        if (decoded is Map<String, dynamic>) {
          values = decoded;
        } else {
          throw const FormatException('settings root is not an object');
        }
      }
    } catch (e) {
      debugPrint('settings.json unreadable ($e) — starting from defaults');
      try {
        await file.copy('${file.path}.corrupt');
      } catch (_) {}
    }
    return SettingsStore._(AtomicFileWriter(file), values);
  }

  /// The value under [key] if it has type [T], otherwise null.
  T? get<T>(String key) {
    final value = _values[key];
    return value is T ? value : null;
  }

  /// Sets (or, for null, removes) [key] and persists all settings.
  Future<void> set(String key, Object? value) {
    if (value == null) {
      _values.remove(key);
    } else {
      _values[key] = value;
    }
    return _writer?.write(jsonEncode(_values)) ?? Future.value();
  }
}
