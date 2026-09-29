import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

class BackgroundTransferService {
  static bool _initialized = false;
  static bool _running = false;

  /// Progress arrives ~10×/s per transfer, but each notification update is
  /// a platform-channel round trip — refreshing about once a second is
  /// plenty for a status line.
  static const _minProgressInterval = Duration(seconds: 1);
  static DateTime _lastProgressAt = DateTime.fromMillisecondsSinceEpoch(0);

  static void init() {
    if (_initialized) return;
    if (!Platform.isAndroid && !Platform.isIOS) {
      _initialized = true;
      return;
    }
    _initialized = true;

    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'takeit_transfer',
        channelName: 'File Transfer',
        channelDescription: 'Transferring files in the background',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: false,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  static Future<void> startIfNeeded() async {
    if (_running) return;
    if (!Platform.isAndroid && !Platform.isIOS) return;

    init();
    // Android 13+ hides the foreground-service notification without this
    // permission. Ask once, on the first transfer; a denial must not block
    // the service itself.
    if (Platform.isAndroid) {
      try {
        final permission =
            await FlutterForegroundTask.checkNotificationPermission();
        if (permission != NotificationPermission.granted) {
          await FlutterForegroundTask.requestNotificationPermission();
        }
      } catch (e) {
        debugPrint('Notification permission check failed: $e');
      }
    }
    await FlutterForegroundTask.startService(
      notificationTitle: 'TakeIt',
      notificationText: 'Transferring files...',
      serviceTypes: [ForegroundServiceTypes.dataSync],
    );
    _running = true;
  }

  static Future<void> updateProgress(String fileName, int percent) async {
    if (!_running) return;
    final now = DateTime.now();
    if (percent < 100 &&
        now.difference(_lastProgressAt) < _minProgressInterval) {
      return;
    }
    _lastProgressAt = now;
    await FlutterForegroundTask.updateService(
      notificationTitle: 'TakeIt',
      notificationText: '$fileName — $percent%',
    );
  }

  static Future<void> stop() async {
    if (!_running) return;
    await FlutterForegroundTask.stopService();
    _running = false;
  }
}
