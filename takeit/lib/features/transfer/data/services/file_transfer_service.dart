import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../../../../core/network/http_client.dart';

class FileTransferService {
  final Dio _client = createHttpClient();

  /// Send a file as a streamed upload to a target device.
  /// Reports progress via [onProgress] callback.
  Future<void> sendFile({
    required String targetIp,
    required int targetPort,
    required String filePath,
    required String sessionId,
    required String fileId,
    required String token,
    required void Function(int sent, int total) onProgress,
    CancelToken? cancelToken,
  }) async {
    final file = File(filePath);
    final fileSize = await file.length();

    // 0-byte files: send empty body directly — streaming an empty stream via dio
    // can stall waiting for data that never arrives.
    final data = fileSize == 0 ? <int>[] : file.openRead();

    await _client.post(
      'http://$targetIp:$targetPort/api/takeit/v1/transfer/upload'
      '?sessionId=$sessionId&fileId=$fileId&token=$token',
      data: data,
      cancelToken: cancelToken,
      options: Options(
        headers: {
          'Content-Type': 'application/octet-stream',
          'Content-Length': fileSize,
        },
      ),
      onSendProgress: (sent, total) {
        onProgress(sent, fileSize);
      },
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
