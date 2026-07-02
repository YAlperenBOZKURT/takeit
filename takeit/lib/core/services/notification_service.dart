import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:local_notifier/local_notifier.dart';
import 'window_alert_service.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static bool _appInForeground = true;
  static bool _soundEnabled = true;
  static bool _vibrationEnabled = true;

  // Notification ID constants to avoid collisions
  static const _idMessage = 1;
  static const _idFileTransfer = 2;
  static const _idRoomInvite = 3;

  static void setAppForeground(bool value) {
    _appInForeground = value;
  }

  static void updateSettings({required bool sound, required bool vibration}) {
    _soundEnabled = sound;
    _vibrationEnabled = vibration;
  }

  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    // Windows: use local_notifier for toast notifications
    if (Platform.isWindows) {
      await localNotifier.setup(appName: 'TakeIt');
      return;
    }

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const linuxSettings = LinuxInitializationSettings(
      defaultActionName: 'Open',
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
      linux: linuxSettings,
    );

    await _plugin.initialize(settings);

    // Request notification permission on Android 13+
    if (Platform.isAndroid) {
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
    }
  }

  static Future<void> showNotification({
    required String title,
    required String body,
    int id = 0,
  }) async {
    if (_appInForeground) return;

    if (!_initialized) await init();

    // Windows: use local_notifier toast + system sound
    if (Platform.isWindows) {
      final notification = LocalNotification(title: title, body: body);
      await notification.show();
      if (_soundEnabled) {
        WindowAlertService.playSound();
      }
      return;
    }

    final androidDetails = AndroidNotificationDetails(
      'takeit_alerts',
      'TakeIt Alerts',
      channelDescription: 'Incoming messages, files, and room invites',
      importance: Importance.high,
      priority: Priority.high,
      playSound: _soundEnabled,
      enableVibration: _vibrationEnabled,
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const linuxDetails = LinuxNotificationDetails();

    final details = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
      linux: linuxDetails,
    );

    await _plugin.show(id, title, body, details);
  }

  static Future<void> notifyMessage(String senderAlias, String content) async {
    await showNotification(title: senderAlias, body: content, id: _idMessage);
  }

  static Future<void> notifyFileTransfer(
    String senderAlias,
    String fileName,
  ) async {
    await showNotification(
      title: senderAlias,
      body: '$senderAlias → $fileName',
      id: _idFileTransfer,
    );
  }

  static Future<void> notifyRoomInvite(String hostAlias) async {
    await showNotification(
      title: 'TakeIt',
      body: '$hostAlias 📨',
      id: _idRoomInvite,
    );
  }
}
