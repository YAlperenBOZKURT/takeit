import 'dart:io';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

class BackgroundTransferService {
  static bool _initialized = false;
  static bool _running = false;

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
    await FlutterForegroundTask.startService(
      notificationTitle: 'TakeIt',
      notificationText: 'Transferring files...',
      serviceTypes: [ForegroundServiceTypes.dataSync],
    );
    _running = true;
  }

  static Future<void> updateProgress(String fileName, int percent) async {
    if (!_running) return;
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
