import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

enum AppThemeMode { system, light, dark, modern, terra }

enum AppLanguage { system, en, tr }

final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, AppThemeMode>((ref) {
      return ThemeModeNotifier();
    });

final languageProvider = StateNotifierProvider<LanguageNotifier, AppLanguage>((
  ref,
) {
  return LanguageNotifier();
});

class ThemeModeNotifier extends StateNotifier<AppThemeMode> {
  ThemeModeNotifier() : super(AppThemeMode.terra) {
    _load();
  }

  Future<File> _getFile() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/settings.json');
  }

  Future<void> _load() async {
    try {
      final file = await _getFile();
      if (!await file.exists()) return;
      final json = jsonDecode(await file.readAsString());
      final mode = json['themeMode'] as String?;
      state = switch (mode) {
        'light' => AppThemeMode.light,
        'dark' => AppThemeMode.dark,
        'modern' => AppThemeMode.modern,
        'terra' => AppThemeMode.terra,
        'system' => AppThemeMode.system,
        _ => AppThemeMode.terra,
      };
    } catch (e) {
      debugPrint('Failed to load theme setting: $e');
    }
  }

  Future<void> setThemeMode(AppThemeMode mode) async {
    state = mode;
    await _save();
  }

  Future<void> _save() async {
    final file = await _getFile();
    Map<String, dynamic> existing = {};
    try {
      if (await file.exists()) {
        existing =
            jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      }
    } catch (_) {}
    existing['themeMode'] = state.name;
    await file.writeAsString(jsonEncode(existing));
  }

  ThemeMode get flutterThemeMode => switch (state) {
    AppThemeMode.light => ThemeMode.light,
    AppThemeMode.terra => ThemeMode.light,
    AppThemeMode.dark => ThemeMode.dark,
    AppThemeMode.modern => ThemeMode.dark,
    AppThemeMode.system => ThemeMode.system,
  };
}

final downloadPathProvider =
    StateNotifierProvider<DownloadPathNotifier, String?>((ref) {
      return DownloadPathNotifier();
    });

class DownloadPathNotifier extends StateNotifier<String?> {
  DownloadPathNotifier() : super(null) {
    _load();
  }

  Future<File> _getFile() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/settings.json');
  }

  Future<void> _load() async {
    try {
      final file = await _getFile();
      if (!await file.exists()) return;
      final json = jsonDecode(await file.readAsString());
      state = json['downloadPath'] as String?;
    } catch (e) {
      debugPrint('Failed to load download path: $e');
    }
  }

  Future<void> setPath(String? path) async {
    state = path;
    await _save();
  }

  Future<void> _save() async {
    final file = await _getFile();
    Map<String, dynamic> existing = {};
    try {
      if (await file.exists()) {
        existing =
            jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      }
    } catch (_) {}
    if (state != null) {
      existing['downloadPath'] = state;
    } else {
      existing.remove('downloadPath');
    }
    await file.writeAsString(jsonEncode(existing));
  }
}

class LanguageNotifier extends StateNotifier<AppLanguage> {
  LanguageNotifier() : super(AppLanguage.system) {
    _load();
  }

  Future<File> _getFile() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/settings.json');
  }

  Future<void> _load() async {
    try {
      final file = await _getFile();
      if (!await file.exists()) return;
      final json = jsonDecode(await file.readAsString());
      final lang = json['language'] as String?;
      state = switch (lang) {
        'en' => AppLanguage.en,
        'tr' => AppLanguage.tr,
        _ => AppLanguage.system,
      };
    } catch (e) {
      debugPrint('Failed to load language setting: $e');
    }
  }

  Future<void> setLanguage(AppLanguage lang) async {
    state = lang;
    await _save();
  }

  Future<void> _save() async {
    final file = await _getFile();
    Map<String, dynamic> existing = {};
    try {
      if (await file.exists()) {
        existing =
            jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      }
    } catch (_) {}
    existing['language'] = state.name;
    await file.writeAsString(jsonEncode(existing));
  }

  Locale? get locale => switch (state) {
    AppLanguage.en => const Locale('en'),
    AppLanguage.tr => const Locale('tr'),
    AppLanguage.system => null,
  };
}

// ─── Notification Sound ───

final notificationSoundProvider =
    StateNotifierProvider<NotificationSoundNotifier, bool>((ref) {
      return NotificationSoundNotifier();
    });

class NotificationSoundNotifier extends StateNotifier<bool> {
  NotificationSoundNotifier() : super(true) {
    _load();
  }

  Future<File> _getFile() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/settings.json');
  }

  Future<void> _load() async {
    try {
      final file = await _getFile();
      if (!await file.exists()) return;
      final json = jsonDecode(await file.readAsString());
      state = json['notificationSound'] as bool? ?? true;
    } catch (e) {
      debugPrint('Failed to load notification sound setting: $e');
    }
  }

  Future<void> toggle() async {
    state = !state;
    await _save();
  }

  Future<void> _save() async {
    final file = await _getFile();
    Map<String, dynamic> existing = {};
    try {
      if (await file.exists()) {
        existing =
            jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      }
    } catch (_) {}
    existing['notificationSound'] = state;
    await file.writeAsString(jsonEncode(existing));
  }
}

// ─── Notification Vibration ───

final notificationVibrationProvider =
    StateNotifierProvider<NotificationVibrationNotifier, bool>((ref) {
      return NotificationVibrationNotifier();
    });

class NotificationVibrationNotifier extends StateNotifier<bool> {
  NotificationVibrationNotifier() : super(true) {
    _load();
  }

  Future<File> _getFile() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/settings.json');
  }

  Future<void> _load() async {
    try {
      final file = await _getFile();
      if (!await file.exists()) return;
      final json = jsonDecode(await file.readAsString());
      state = json['notificationVibration'] as bool? ?? true;
    } catch (e) {
      debugPrint('Failed to load notification vibration setting: $e');
    }
  }

  Future<void> toggle() async {
    state = !state;
    await _save();
  }

  Future<void> _save() async {
    final file = await _getFile();
    Map<String, dynamic> existing = {};
    try {
      if (await file.exists()) {
        existing =
            jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      }
    } catch (_) {}
    existing['notificationVibration'] = state;
    await file.writeAsString(jsonEncode(existing));
  }
}
