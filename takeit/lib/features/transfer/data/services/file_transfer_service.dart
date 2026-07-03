import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../../../../core/network/http_client.dart';

/// How long an incoming upload stream may go silent before the receiver
/// fails the transfer. Long enough to survive brief Wi-Fi hiccups.
const kReceiveStallTimeout = Duration(seconds: 60);

/// Receivers flush to disk every this many bytes so the IOSink write buffer
/// stays bounded when the disk is slower than the network.
const kReceiveFlushBytes = 8 * 1024 * 1024;

/// How long a disk flush/close may take before the receiver fails the
/// transfer. `IOSink.add` never throws for a failed write (it's
/// fire-and-forget) — a full disk or a stuck storage layer only ever
/// surfaces at `flush()`/`close()`, and on some platforms that call can hang
/// instead of throwing promptly. Without this bound, a stuck write leaves
/// the transfer showing "in progress" forever on both ends.
const kWriteStallTimeout = Duration(seconds: 20);

class FileTransferService {
  final Dio _client = createHttpClient();

  /// No-progress window after which an outgoing upload is aborted. Must be
  /// longer than the receiver's 120s download-slot wait, during which no
  /// bytes flow even though the transfer is healthy.
  static const uploadStallTimeout = Duration(seconds: 150);
  static const _defaultStallCheckInterval = Duration(seconds: 5);

  final Duration _stallTimeout;
  final Duration _stallCheckInterval;

  /// [stallTimeout] and [stallCheckInterval] exist so tests can exercise the
  /// watchdog without waiting minutes; production uses the defaults.
  FileTransferService({
    Duration stallTimeout = uploadStallTimeout,
    Duration stallCheckInterval = _defaultStallCheckInterval,
  }) : _stallTimeout = stallTimeout,
       _stallCheckInterval = stallCheckInterval;

  /// Send a file as a streamed upload to a target device.
  /// Reports progress via [onProgress] callback.
  Future<void> sendFile({
    required String targetIp,
    required int targetPort,
    required String filePath,
    required String sessionId,
    String? fileId,
    required String token,
    required void Function(int sent, int total) onProgress,
    CancelToken? cancelToken,
    String uploadPath = '/api/takeit/v1/transfer/upload',
  }) async {
    final file = File(filePath);
    final fileSize = await file.length();

    // 0-byte files: send empty body directly — streaming an empty stream via dio
    // can stall waiting for data that never arrives.
    final data = fileSize == 0 ? <int>[] : file.openRead();

    // Internal token so a stall abort is distinguishable from a user cancel.
    final abortToken = CancelToken();
    cancelToken?.whenCancel.then((_) {
      if (!abortToken.isCancelled) abortToken.cancel('user_cancelled');
    });

    var lastSent = 0;
    var lastProgressAt = DateTime.now();
    var stalled = false;
    // Only polices the body-send phase: once every byte is handed to the
    // socket the response wait is receiveTimeout's job, and progress can no
    // longer advance to keep the watchdog fed.
    final watchdog = Timer.periodic(_stallCheckInterval, (_) {
      if (lastSent < fileSize &&
          DateTime.now().difference(lastProgressAt) > _stallTimeout &&
          !abortToken.isCancelled) {
        stalled = true;
        abortToken.cancel('stalled');
      }
    });

    final startedAt = DateTime.now();
    debugPrint(
      'Upload start: $filePath ($fileSize bytes) → '
      '$targetIp:$targetPort$uploadPath',
    );

    try {
      await _client.post(
        'http://$targetIp:$targetPort$uploadPath'
        '?sessionId=$sessionId'
        '${fileId != null ? '&fileId=$fileId' : ''}'
        '&token=$token',
        data: data,
        cancelToken: abortToken,
        options: Options(
          headers: {
            'Content-Type': 'application/octet-stream',
            'Content-Length': fileSize,
          },
          // dio applies sendTimeout to the WHOLE request body, so any fixed
          // value caps total transfer duration (30s ≈ 1 GB on a fast LAN) and
          // large files abort mid-flight. Disable it; the stall watchdog
          // above handles dead connections instead.
          sendTimeout: Duration.zero,
          // The receiver only responds after flushing the file to disk —
          // give slow storage more room than the 30s client default.
          receiveTimeout: const Duration(minutes: 2),
        ),
        onSendProgress: (sent, total) {
          if (sent > lastSent) {
            lastSent = sent;
            lastProgressAt = DateTime.now();
          }
          onProgress(sent, fileSize);
        },
      );
    } on DioException catch (e) {
      final elapsed = DateTime.now().difference(startedAt).inSeconds;
      if (stalled && CancelToken.isCancel(e)) {
        debugPrint(
          'Upload stalled: $filePath — no progress for '
          '${_stallTimeout.inSeconds}s ($lastSent/$fileSize bytes sent)',
        );
        throw TimeoutException(
          'Upload stalled: no progress for ${_stallTimeout.inSeconds}s '
          '($lastSent of $fileSize bytes sent)',
        );
      }
      debugPrint(
        'Upload failed (${e.type}) after $lastSent/$fileSize bytes '
        'in ${elapsed}s: ${e.message}',
      );
      rethrow;
    } finally {
      watchdog.cancel();
    }

    debugPrint(
      'Upload done: $filePath ($fileSize bytes) in '
      '${DateTime.now().difference(startedAt).inSeconds}s',
    );

    // onSendProgress may not fire for zero-length bodies — force-complete the callback.
    if (fileSize == 0) onProgress(0, 0);
  }

  /// Get the save path for a received file, handling name collisions.
  /// If [customDir] is set, use that instead of the default downloads directory.
  Future<String> getSavePath(String fileName, {String? customDir}) async {
    final safeName = sanitizeFileName(fileName);

    final dir = customDir != null
        ? Directory(customDir)
        : await _getDownloadsDir();

    // Ensure directory exists
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    var file = File('${dir.path}/$safeName');

    if (!await file.exists()) return file.path;

    final dotIndex = safeName.lastIndexOf('.');
    final name = dotIndex > 0 ? safeName.substring(0, dotIndex) : safeName;
    final ext = dotIndex > 0 ? safeName.substring(dotIndex) : '';

    var counter = 1;
    while (await file.exists()) {
      file = File('${dir.path}/${name}_$counter$ext');
      counter++;
    }
    return file.path;
  }

  /// Strip path separators, traversal fragments, and control chars.
  /// Also prefix Windows reserved names so they don't clash with device namespace.
  @visibleForTesting
  static String sanitizeFileName(String raw) {
    // Keep only the basename — drop any directory components the sender may have snuck in.
    var name = raw.split(RegExp(r'[/\\]')).last;

    // Remove traversal artifacts and illegal chars.
    name = name.replaceAll('..', '_');
    name = name.replaceAll(RegExp(r'[\x00-\x1f<>:"|?*]'), '_');
    name = name.trim();

    if (name.isEmpty || name == '.' || name == '..') {
      name = 'file';
    }

    // Windows reserved device names — prefix so they don't resolve to devices.
    const reserved = {
      'CON',
      'PRN',
      'AUX',
      'NUL',
      'COM1',
      'COM2',
      'COM3',
      'COM4',
      'COM5',
      'COM6',
      'COM7',
      'COM8',
      'COM9',
      'LPT1',
      'LPT2',
      'LPT3',
      'LPT4',
      'LPT5',
      'LPT6',
      'LPT7',
      'LPT8',
      'LPT9',
    };
    final dotIndex = name.indexOf('.');
    final stem = dotIndex > 0 ? name.substring(0, dotIndex) : name;
    if (reserved.contains(stem.toUpperCase())) {
      name = '_$name';
    }

    return name;
  }

  Future<Directory> _getDownloadsDir() async {
    // Android: write to the public Downloads/TakeIt folder so users can
    // actually find the files in their Files app. path_provider's
    // getDownloadsDirectory() returns null on Android, and the fallback
    // (app documents dir) is sandboxed and invisible to the user.
    if (Platform.isAndroid) {
      try {
        final publicDir = Directory('/storage/emulated/0/Download/TakeIt');
        if (!await publicDir.exists()) {
          await publicDir.create(recursive: true);
        }
        // Probe write access — on restrictive OEMs we may not be allowed.
        final probe = File('${publicDir.path}/.write_test');
        await probe.writeAsBytes(const [], flush: true);
        await probe.delete();
        return publicDir;
      } catch (_) {
        // Fall through to sandbox fallback.
      }
      final ext = await getExternalStorageDirectory();
      if (ext != null) return ext;
    }
    final dir = await getDownloadsDirectory();
    if (dir != null) return dir;
    return getApplicationDocumentsDirectory();
  }
}
