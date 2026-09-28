import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/storage/settings_store.dart';

enum AppThemeMode { system, light, dark, modern, terra }

enum AppLanguage { system, en, tr }

final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, AppThemeMode>((ref) {
      return ThemeModeNotifier(ref.read(settingsStoreProvider));
    });

final languageProvider = StateNotifierProvider<LanguageNotifier, AppLanguage>((
  ref,
) {
  return LanguageNotifier(ref.read(settingsStoreProvider));
});

class ThemeModeNotifier extends StateNotifier<AppThemeMode> {
  final SettingsStore _store;

  ThemeModeNotifier(this._store)
    : super(switch (_store.get<String>('themeMode')) {
        'light' => AppThemeMode.light,
        'dark' => AppThemeMode.dark,
        'modern' => AppThemeMode.modern,
        'system' => AppThemeMode.system,
        _ => AppThemeMode.terra,
      });

  Future<void> setThemeMode(AppThemeMode mode) {
    state = mode;
    return _store.set('themeMode', mode.name);
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
      return DownloadPathNotifier(ref.read(settingsStoreProvider));
    });

class DownloadPathNotifier extends StateNotifier<String?> {
  final SettingsStore _store;

  DownloadPathNotifier(this._store) : super(_store.get<String>('downloadPath'));

  Future<void> setPath(String? path) {
    state = path;
    return _store.set('downloadPath', path);
  }
}

class LanguageNotifier extends StateNotifier<AppLanguage> {
  final SettingsStore _store;

  LanguageNotifier(this._store)
    : super(switch (_store.get<String>('language')) {
        'en' => AppLanguage.en,
        'tr' => AppLanguage.tr,
        _ => AppLanguage.system,
      });

  Future<void> setLanguage(AppLanguage lang) {
    state = lang;
    return _store.set('language', lang.name);
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
      return NotificationSoundNotifier(ref.read(settingsStoreProvider));
    });

class NotificationSoundNotifier extends StateNotifier<bool> {
  final SettingsStore _store;

  NotificationSoundNotifier(this._store)
    : super(_store.get<bool>('notificationSound') ?? true);

  Future<void> toggle() {
    state = !state;
    return _store.set('notificationSound', state);
  }
}

// ─── Notification Vibration ───

final notificationVibrationProvider =
    StateNotifierProvider<NotificationVibrationNotifier, bool>((ref) {
      return NotificationVibrationNotifier(ref.read(settingsStoreProvider));
    });

class NotificationVibrationNotifier extends StateNotifier<bool> {
  final SettingsStore _store;

  NotificationVibrationNotifier(this._store)
    : super(_store.get<bool>('notificationVibration') ?? true);

  Future<void> toggle() {
    state = !state;
    return _store.set('notificationVibration', state);
  }
}
