import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'app.dart';
import 'core/network/http_server.dart';
import 'core/services/background_transfer_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/window_alert_service.dart';
import 'core/storage/settings_store.dart';
import 'features/discovery/presentation/providers/discovery_provider.dart';

final httpServerProvider = Provider<AppHttpServer>((ref) {
  throw UnimplementedError('httpServerProvider must be overridden');
});

/// Holds the server startup error message, if any (e.g. port already in use).
final serverErrorProvider = Provider<String?>((ref) => null);

/// Pre-loaded nickname from settings.json (empty string if none saved).
final initialNicknameProvider = Provider<String>((ref) => '');

/// The persistent device id. Created once and stored with the settings, so
/// restarts keep the same identity (no ghost duplicates on peers).
Future<String> _loadOrCreateFingerprint(SettingsStore settings) async {
  final saved = settings.get<String>('fingerprint');
  if (saved != null && saved.isNotEmpty) return saved;
  final fingerprint = const Uuid().v4();
  await settings.set('fingerprint', fingerprint);
  return fingerprint;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  BackgroundTransferService.init();
  await NotificationService.init();
  final settings = await SettingsStore.open();
  NotificationService.updateSettings(
    sound: settings.get<bool>('notificationSound') ?? true,
    vibration: settings.get<bool>('notificationVibration') ?? true,
  );
  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
    await WindowAlertService.init();
  }
  final server = AppHttpServer();
  String? serverError;
  try {
    await server.start();
  } on SocketException catch (e) {
    serverError = e.message;
    debugPrint('Server failed to start: $e');
  }
  final fingerprint = await _loadOrCreateFingerprint(settings);
  runApp(
    ProviderScope(
      overrides: [
        settingsStoreProvider.overrideWithValue(settings),
        httpServerProvider.overrideWithValue(server),
        initialNicknameProvider.overrideWithValue(
          settings.get<String>('nickname') ?? '',
        ),
        serverErrorProvider.overrideWithValue(serverError),
        fingerprintProvider.overrideWithValue(fingerprint),
      ],
      child: const TakeItApp(),
    ),
  );
}
