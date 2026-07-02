import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'app.dart';
import 'core/network/http_server.dart';
import 'core/services/background_transfer_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/window_alert_service.dart';
import 'features/discovery/presentation/providers/discovery_provider.dart';

final httpServerProvider = Provider<AppHttpServer>((ref) {
  throw UnimplementedError('httpServerProvider must be overridden');
});

/// Holds the server startup error message, if any (e.g. port already in use).
final serverErrorProvider = Provider<String?>((ref) => null);

/// Pre-loaded nickname from settings.json (empty string if none saved).
final initialNicknameProvider = Provider<String>((ref) => '');

Future<String> _loadSavedNickname() async {
  try {
    final dir = await getApplicationSupportDirectory();
    final file = File('${dir.path}/settings.json');
    if (!await file.exists()) return '';
    final json = jsonDecode(await file.readAsString());
    return (json['nickname'] as String?) ?? '';
  } catch (e) {
    debugPrint('Failed to load nickname: $e');
    return '';
  }
}

Future<String> _loadOrCreateFingerprint() async {
  try {
    final dir = await getApplicationSupportDirectory();
    final file = File('${dir.path}/settings.json');
    Map<String, dynamic> existing = {};
    if (await file.exists()) {
      existing = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    }
    final saved = existing['fingerprint'] as String?;
    if (saved != null && saved.isNotEmpty) return saved;
    final newFp = const Uuid().v4();
    existing['fingerprint'] = newFp;
    await file.writeAsString(jsonEncode(existing));
    return newFp;
  } catch (e) {
    debugPrint('Failed to load/create fingerprint: $e');
    return const Uuid().v4();
  }
}

Future<void> _loadNotificationSettings() async {
  try {
    final dir = await getApplicationSupportDirectory();
    final file = File('${dir.path}/settings.json');
    if (!await file.exists()) return;
    final json = jsonDecode(await file.readAsString());
    final sound = json['notificationSound'] as bool? ?? true;
    final vibration = json['notificationVibration'] as bool? ?? true;
    NotificationService.updateSettings(sound: sound, vibration: vibration);
  } catch (e) {
    debugPrint('Failed to load notification settings: $e');
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  BackgroundTransferService.init();
  await NotificationService.init();
  await _loadNotificationSettings();
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
  final savedNickname = await _loadSavedNickname();
  final fingerprint = await _loadOrCreateFingerprint();
  runApp(
    ProviderScope(
      overrides: [
        httpServerProvider.overrideWithValue(server),
        initialNicknameProvider.overrideWithValue(savedNickname),
        serverErrorProvider.overrideWithValue(serverError),
        fingerprintProvider.overrideWithValue(fingerprint),
      ],
      child: const TakeItApp(),
    ),
  );
}
