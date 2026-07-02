import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:shelf/shelf.dart' as shelf;
import '../../../../core/network/http_client.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/services/transfer_queue_service.dart';
import '../../../../core/services/window_alert_service.dart';
import '../../../../main.dart';
import '../../../discovery/domain/entities/device.dart';
import '../../../discovery/presentation/providers/discovery_provider.dart';
import '../../../history/presentation/providers/history_provider.dart';
import '../../../nickname/presentation/providers/nickname_provider.dart';
import '../../../settings/presentation/providers/settings_provider.dart';
import '../../../transfer/data/services/file_transfer_service.dart';
import '../../../transfer/domain/entities/transfer_session.dart';

/// Incoming quick text shown in popup.
final incomingQuickTextProvider = StateProvider<QuickTextMessage?>(
  (ref) => null,
);

/// Active quick send transfers (sender side progress tracking).
final quickTransfersProvider =
    StateNotifierProvider<QuickTransferNotifier, List<TransferSession>>((ref) {
      return QuickTransferNotifier(ref);
    });

class QuickTextMessage {
  final String senderId;
  final String senderAlias;
  final String content;
  final DateTime timestamp;

  QuickTextMessage({
    required this.senderId,
    required this.senderAlias,
    required this.content,
    required this.timestamp,
  });
}

class QuickTransferNotifier extends StateNotifier<List<TransferSession>> {
  final Ref _ref;
  final Dio _client = createHttpClient();
  final FileTransferService _service = FileTransferService();

  /// Accepted sessions waiting for upload (sessionId → metadata).
  final Map<String, _AcceptedQuickSession> _acceptedSessions = {};

  /// Active outgoing sends, keyed by local sessionId.
  final Map<String, _ActiveQuickSend> _activeSends = {};

  /// Retry info for failed outgoing sends, keyed by local sessionId.
  final Map<String, _QuickRetryInfo> _retryInfos = {};

  QuickTransferNotifier(this._ref) : super([]) {
    _registerHandlers();
  }

  @override
  void dispose() {
    final server = _ref.read(httpServerProvider);
    server.unregisterHandler('/api/takeit/v1/quick/prepare-batch');
    server.unregisterHandler('/api/takeit/v1/quick/upload');
    server.unregisterHandler('/api/takeit/v1/quick/text');
    server.unregisterHandler('/api/takeit/v1/quick/cancel');
    for (final t in _progressTimers.values) {
      t?.cancel();
    }
    super.dispose();
  }

  void _registerHandlers() {
    final server = _ref.read(httpServerProvider);
    server.registerHandler(
      '/api/takeit/v1/quick/prepare-batch',
      _handlePrepareBatch,
    );
    server.registerHandler('/api/takeit/v1/quick/upload', _handleUpload);
    server.registerHandler('/api/takeit/v1/quick/text', _handleText);
    server.registerHandler('/api/takeit/v1/quick/cancel', _handleCancel);
  }

  Future<shelf.Response> _handleCancel(shelf.Request request) async {
    final params = request.url.queryParameters;
    final sessionId = params['sessionId'];
    if (sessionId != null) {
      _updateSession(
        sessionId,
        (s) => s.copyWith(status: TransferStatus.cancelled),
      );
    }
    return shelf.Response.ok(
      jsonEncode({'status': 'cancelled'}),
      headers: {'Content-Type': 'application/json'},
    );
  }

  // ─── Receiver side (uses global queue) ───

  Future<shelf.Response> _handlePrepareBatch(shelf.Request request) async {
    final body = jsonDecode(await request.readAsString());
    final batchId = body['batchId'] as String? ?? const Uuid().v4();
    final senderId = body['senderId'] as String?;
    final senderAlias = body['senderAlias'] as String?;
    final filesJson = body['files'] as List?;

    if (senderId == null ||
        senderAlias == null ||
        filesJson == null ||
        filesJson.isEmpty) {
      return shelf.Response.badRequest(
        body: jsonEncode({'error': 'Missing required fields'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    final senderIp = request.headers['x-real-ip'] ?? '';

    final batchedFiles = <BatchedFile>[];
    for (final f in filesJson) {
      final fileName = f['fileName'] as String?;
      final fileSize = f['fileSize'] as int?;
      if (fileName == null || fileSize == null) {
        return shelf.Response.badRequest(
          body: jsonEncode({'error': 'Invalid file entry'}),
          headers: {'Content-Type': 'application/json'},
        );
      }
      final bf =
          BatchedFile(
              fileName: fileName,
              fileSize: fileSize,
              fileMimeType: f['fileMimeType'] as String?,
            )
            ..sessionId = const Uuid().v4()
            ..token = const Uuid().v4();
      batchedFiles.add(bf);
    }

    final first = batchedFiles.first.fileName;
    final notifTitle = batchedFiles.length == 1
        ? first
        : '$first (+${batchedFiles.length - 1})';
    NotificationService.notifyFileTransfer(senderAlias, notifTitle);
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      WindowAlertService.flashWindow();
    }

    final queue = _ref.read(transferQueueProvider);
    final batch = TransferBatch(
      batchId: batchId,
      senderId: senderId,
      senderAlias: senderAlias,
      senderIp: senderIp,
      source: TransferSource.quick,
      files: batchedFiles,
      approvalCompleter: Completer<List<bool>>(),
    );

    final results = await queue.enqueueBatch(batch);

    final responseFiles = <Map<String, dynamic>>[];
    for (var i = 0; i < batchedFiles.length; i++) {
      final bf = batchedFiles[i];
      final accepted = i < results.length && results[i];
      final entry = <String, dynamic>{'index': i, 'accepted': accepted};
      if (accepted) {
        _acceptedSessions[bf.sessionId!] = _AcceptedQuickSession(
          sessionId: bf.sessionId!,
          token: bf.token!,
          fileName: bf.fileName,
          fileSize: bf.fileSize,
          senderId: senderId,
          senderAlias: senderAlias,
          fileMimeType: bf.fileMimeType,
        );
        entry['sessionId'] = bf.sessionId;
        entry['token'] = bf.token;

        final sid = bf.sessionId!;
        Timer(const Duration(seconds: 120), () {
          if (_acceptedSessions.remove(sid) != null) {
            debugPrint('Quick accepted session $sid expired without upload');
          }
        });
      }
      responseFiles.add(entry);
    }

    return shelf.Response.ok(
      jsonEncode({'batchId': batchId, 'files': responseFiles}),
      headers: {'Content-Type': 'application/json'},
    );
  }

  Future<shelf.Response> _handleUpload(shelf.Request request) async {
    final params = request.url.queryParameters;
    final sessionId = params['sessionId'];
    final token = params['token'];

    if (sessionId == null || token == null) {
      return shelf.Response.badRequest(body: 'Missing sessionId or token');
    }

    // Keep the accepted session until the upload fully completes so a dropped
    // connection can be retried with the same approval (expires after 120s).
    final accepted = _acceptedSessions[sessionId];
    if (accepted == null || accepted.token != token) {
      return shelf.Response.forbidden('Invalid session or token');
    }

    // Reject a second concurrent upload for the same session (would clobber
    // the file mid-write); a retry after a *failed* attempt is still allowed.
    final existing = state.where((s) => s.sessionId == sessionId).firstOrNull;
    if (existing?.status == TransferStatus.inProgress) {
      return shelf.Response(
        409,
        body: jsonEncode({'status': 'failed', 'error': 'already_in_progress'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    final queue = _ref.read(transferQueueProvider);
    final gotSlot = await queue.waitForDownloadSlot(sessionId);
    if (!gotSlot) {
      queue.downloadFailed(
        sessionId,
        reason: 'Timed out waiting for download slot',
      );
      return shelf.Response.internalServerError(
        body: jsonEncode({'status': 'failed', 'error': 'Queue timeout'}),
      );
    }

    final customDir = _ref.read(downloadPathProvider);
    final savePath = await _service.getSavePath(
      accepted.fileName,
      customDir: customDir,
    );

    final session = TransferSession(
      sessionId: sessionId,
      fileId: '',
      fileName: accepted.fileName,
      fileSize: accepted.fileSize,
      senderId: accepted.senderId,
      senderAlias: accepted.senderAlias,
      fileMimeType: accepted.fileMimeType,
      direction: TransferDirection.receiving,
      token: token,
      status: TransferStatus.inProgress,
      savePath: savePath,
      startedAt: DateTime.now(),
    );
    // Replace any prior (failed) attempt for this session rather than stacking.
    state = [...state.where((s) => s.sessionId != sessionId), session];

    IOSink? sink;
    try {
      final file = File(savePath);
      sink = file.openWrite();
      var bytesReceived = 0;
      var lastChunkTime = DateTime.now();

      await for (final chunk in request.read()) {
        final now = DateTime.now();
        if (now.difference(lastChunkTime) > const Duration(seconds: 30)) {
          throw TimeoutException('No data for 30s — sender disconnected');
        }

        final current = state
            .where((s) => s.sessionId == sessionId)
            .firstOrNull;
        if (current?.status == TransferStatus.cancelled) {
          throw _QuickReceiverCancelled();
        }

        sink.add(chunk);
        bytesReceived += chunk.length;
        lastChunkTime = now;
        _updateProgress(sessionId, bytesReceived);
      }

      await sink.flush();
      await sink.close();
      sink = null;

      // Reject truncated/over-long transfers instead of reporting success.
      if (bytesReceived != accepted.fileSize) {
        throw Exception(
          'Incomplete transfer: received $bytesReceived of '
          '${accepted.fileSize} bytes',
        );
      }

      // Fully received — release the approval so it can't be replayed.
      _acceptedSessions.remove(sessionId);

      _flushProgress(sessionId);
      _updateSession(
        sessionId,
        (s) => s.copyWith(status: TransferStatus.completed),
      );
      queue.downloadCompleted(sessionId, senderAlias: accepted.senderAlias);

      _ref
          .read(historyProvider.notifier)
          .addRecord(
            fileName: accepted.fileName,
            fileSize: accepted.fileSize,
            peerAlias: accepted.senderAlias,
            direction: 'received',
            fileMimeType: accepted.fileMimeType,
            savePath: savePath,
          );

      return shelf.Response.ok(
        jsonEncode({'status': 'completed'}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      debugPrint('Quick upload receive error: $e');
      final isCancel = e is _QuickReceiverCancelled;
      _flushProgress(sessionId);
      _updateSession(
        sessionId,
        (s) => s.copyWith(
          status: isCancel ? TransferStatus.cancelled : TransferStatus.failed,
        ),
      );
      queue.downloadFailed(sessionId, reason: e.toString());

      // Close sink before deleting — on Windows open files cannot be deleted.
      try {
        await sink?.close();
      } catch (_) {}
      sink = null;

      try {
        final partial = File(savePath);
        if (await partial.exists()) await partial.delete();
      } catch (_) {}

      return shelf.Response.internalServerError(
        body: jsonEncode({
          'status': isCancel ? 'cancelled' : 'failed',
          'error': e.toString(),
        }),
      );
    } finally {
      try {
        await sink?.close();
      } catch (_) {}
    }
  }

  Future<shelf.Response> _handleText(shelf.Request request) async {
    final body = jsonDecode(await request.readAsString());
    final senderId = body['senderId'] as String?;
    final senderAlias = body['senderAlias'] as String?;
    final content = body['content'] as String?;

    if (senderId == null || senderAlias == null || content == null) {
      return shelf.Response.badRequest(
        body: jsonEncode({'error': 'Missing required fields'}),
        headers: {'Content-Type': 'application/json'},
      );
    }

    final message = QuickTextMessage(
      senderId: senderId,
      senderAlias: senderAlias,
      content: content,
      timestamp: DateTime.now(),
    );

    _ref.read(incomingQuickTextProvider.notifier).state = message;

    NotificationService.notifyMessage(message.senderAlias, message.content);
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      WindowAlertService.flashWindow();
    }

    _ref
        .read(historyProvider.notifier)
        .addRecord(
          fileName: 'Quick Text',
          fileSize: message.content.length,
          peerAlias: message.senderAlias,
          direction: 'clipboard_received',
          savePath: message.content,
        );

    return shelf.Response.ok(
      jsonEncode({'status': 'ok'}),
      headers: {'Content-Type': 'application/json'},
    );
  }

  // ─── Sender side ───

  /// Returns true on successful completion of ALL files, false if any failed.
  Future<bool> sendFile({
    required Device target,
    required String filePath,
    required String fileName,
    required int fileSize,
    String? fileMimeType,
  }) {
    return sendFiles(
      target: target,
      files: [
        QuickOutgoingFile(
          filePath: filePath,
          fileName: fileName,
          fileSize: fileSize,
          fileMimeType: fileMimeType,
        ),
      ],
    );
  }

  /// Send a batch of files to a single target in one approval round.
  ///
  /// [onSessionsCreated], if given, fires synchronously with the local
  /// session ids (same order as [files]) before any network call — callers
  /// that need to track per-file progress (e.g. an inline sending UI) can use
  /// it to start watching [quickTransfersProvider] for those ids right away.
  Future<bool> sendFiles({
    required Device target,
    required List<QuickOutgoingFile> files,
    void Function(List<String> sessionIds)? onSessionsCreated,
  }) async {
    if (files.isEmpty) return true;
    final fingerprint = _ref.read(fingerprintProvider);
    final alias = _ref.read(nicknameProvider);

    final localSessionIds = <String>[];
    for (final f in files) {
      final sid = const Uuid().v4();
      localSessionIds.add(sid);
      state = [
        ...state,
        TransferSession(
          sessionId: sid,
          fileId: '',
          fileName: f.fileName,
          fileSize: f.fileSize,
          senderId: fingerprint,
          senderAlias: alias,
          fileMimeType: f.fileMimeType,
          direction: TransferDirection.sending,
          savePath: f.filePath,
        ),
      ];
    }
    onSessionsCreated?.call(localSessionIds);

    List<dynamic>? results;
    try {
      final response = await _client.post(
        'http://${target.ip}:${target.port}/api/takeit/v1/quick/prepare-batch',
        data: {
          'batchId': const Uuid().v4(),
          'senderId': fingerprint,
          'senderAlias': alias,
          'files': [
            for (final f in files)
              {
                'fileName': f.fileName,
                'fileSize': f.fileSize,
                'fileMimeType': f.fileMimeType,
              },
          ],
        },
        options: Options(receiveTimeout: const Duration(seconds: 125)),
      );
      if (response.statusCode != 200) {
        for (final sid in localSessionIds) {
          _updateSession(
            sid,
            (s) => s.copyWith(status: TransferStatus.declined),
          );
        }
        return false;
      }
      results = (response.data as Map<String, dynamic>)['files'] as List;
    } catch (e) {
      debugPrint('Quick prepare-batch to ${target.alias} failed: $e');
      for (var i = 0; i < localSessionIds.length; i++) {
        _updateSession(
          localSessionIds[i],
          (s) => s.copyWith(status: TransferStatus.failed),
        );
        _retryInfos[localSessionIds[i]] = _QuickRetryInfo(
          targetIp: target.ip,
          targetPort: target.port,
          targetAlias: target.alias,
        );
      }
      return false;
    }

    var allOk = true;
    for (var i = 0; i < files.length; i++) {
      final sid = localSessionIds[i];
      final f = files[i];
      final entry = i < results.length
          ? results[i] as Map<String, dynamic>
          : null;
      final accepted = entry != null && entry['accepted'] == true;
      if (!accepted) {
        _updateSession(sid, (s) => s.copyWith(status: TransferStatus.declined));
        allOk = false;
        continue;
      }
      final ok = await _uploadOneQuickFile(
        localSessionId: sid,
        target: target,
        file: f,
        remoteSessionId: entry['sessionId'] as String,
        token: entry['token'] as String,
      );
      if (!ok) allOk = false;
    }
    return allOk;
  }

  Future<bool> _uploadOneQuickFile({
    required String localSessionId,
    required Device target,
    required QuickOutgoingFile file,
    required String remoteSessionId,
    required String token,
  }) async {
    // Guard: user may have cancelled before we register the active send.
    final preCheck = state
        .where((s) => s.sessionId == localSessionId)
        .firstOrNull;
    if (preCheck?.status == TransferStatus.cancelled) return false;

    final cancelToken = CancelToken();
    _activeSends[localSessionId] = _ActiveQuickSend(
      cancelToken: cancelToken,
      remoteSessionId: remoteSessionId,
      targetIp: target.ip,
      targetPort: target.port,
    );

    _updateSession(
      localSessionId,
      (s) => s.copyWith(
        status: TransferStatus.inProgress,
        startedAt: DateTime.now(),
      ),
    );

    try {
      final f = File(file.filePath);
      final body = file.fileSize == 0 ? <int>[] : f.openRead();
      await _client.post(
        'http://${target.ip}:${target.port}/api/takeit/v1/quick/upload'
        '?sessionId=$remoteSessionId&token=$token',
        data: body,
        cancelToken: cancelToken,
        options: Options(
          headers: {
            'Content-Type': 'application/octet-stream',
            'Content-Length': file.fileSize,
          },
        ),
        onSendProgress: (sent, total) {
          _updateProgress(localSessionId, sent);
        },
      );

      _flushProgress(localSessionId);
      _updateSession(
        localSessionId,
        (s) => s.copyWith(status: TransferStatus.completed),
      );

      _ref
          .read(historyProvider.notifier)
          .addRecord(
            fileName: file.fileName,
            fileSize: file.fileSize,
            peerAlias: target.alias,
            direction: 'sent',
            fileMimeType: file.fileMimeType,
            savePath: file.filePath,
          );
      return true;
    } catch (e) {
      debugPrint('Quick upload ${file.fileName} failed: $e');
      _flushProgress(localSessionId);
      final currentStatus = state
          .where((s) => s.sessionId == localSessionId)
          .map((s) => s.status)
          .firstOrNull;
      if (currentStatus == TransferStatus.cancelled) {
        // Already marked cancelled by user.
      } else if (e is DioException && CancelToken.isCancel(e)) {
        _updateSession(
          localSessionId,
          (s) => s.copyWith(status: TransferStatus.cancelled),
        );
      } else if (e is DioException && e.response?.statusCode == 403) {
        _updateSession(
          localSessionId,
          (s) => s.copyWith(status: TransferStatus.declined),
        );
      } else {
        _updateSession(
          localSessionId,
          (s) => s.copyWith(status: TransferStatus.failed),
        );
        _retryInfos[localSessionId] = _QuickRetryInfo(
          targetIp: target.ip,
          targetPort: target.port,
          targetAlias: target.alias,
        );
      }
      return false;
    } finally {
      _activeSends.remove(localSessionId);
    }
  }

  /// Returns true on successful delivery, false on failure (offline, network error).
  Future<bool> sendText({
    required Device target,
    required String content,
  }) async {
    final fingerprint = _ref.read(fingerprintProvider);
    final alias = _ref.read(nicknameProvider);

    try {
      await _client.post(
        'http://${target.ip}:${target.port}/api/takeit/v1/quick/text',
        data: {
          'senderId': fingerprint,
          'senderAlias': alias,
          'content': content,
        },
      );

      _ref
          .read(historyProvider.notifier)
          .addRecord(
            fileName: 'Quick Text',
            fileSize: content.length,
            peerAlias: target.alias,
            direction: 'clipboard_sent',
            savePath: content,
          );
      return true;
    } catch (e) {
      debugPrint('Quick text send failed: $e');
      return false;
    }
  }

  void cancelSession(String sessionId) {
    _updateSession(
      sessionId,
      (s) => s.copyWith(status: TransferStatus.cancelled),
    );

    final active = _activeSends.remove(sessionId);
    if (active != null) {
      if (!active.cancelToken.isCancelled) {
        active.cancelToken.cancel('user_cancelled');
      }
      () async {
        try {
          await _client.post(
            'http://${active.targetIp}:${active.targetPort}/api/takeit/v1/quick/cancel'
            '?sessionId=${active.remoteSessionId}',
            options: Options(
              sendTimeout: const Duration(seconds: 3),
              receiveTimeout: const Duration(seconds: 3),
            ),
          );
        } catch (_) {}
      }();
    }
  }

  /// Retry a failed outgoing quick send.
  Future<void> retrySession(String sessionId) async {
    final session = state.where((s) => s.sessionId == sessionId).firstOrNull;
    if (session == null) return;
    if (session.direction != TransferDirection.sending) return;
    if (session.status != TransferStatus.failed) return;

    final retry = _retryInfos.remove(sessionId);
    if (retry == null) return;
    final filePath = session.savePath;
    if (filePath == null || !await File(filePath).exists()) return;

    state = state.where((s) => s.sessionId != sessionId).toList();

    await sendFile(
      target: Device(
        fingerprint: '',
        alias: retry.targetAlias,
        deviceType: '',
        ip: retry.targetIp,
        port: retry.targetPort,
        lastSeen: DateTime.now(),
      ),
      filePath: filePath,
      fileName: session.fileName,
      fileSize: session.fileSize,
      fileMimeType: session.fileMimeType,
    );
  }

  bool canRetry(String sessionId) {
    return _retryInfos.containsKey(sessionId);
  }

  /// Throttle timers for progress updates — avoids creating a new list for every chunk.
  final Map<String, Timer?> _progressTimers = {};
  final Map<String, int> _pendingBytes = {};

  void _updateProgress(String sessionId, int bytesTransferred) {
    _pendingBytes[sessionId] = bytesTransferred;
    if (_progressTimers[sessionId] != null) return;
    _progressTimers[sessionId] = Timer(const Duration(milliseconds: 100), () {
      _progressTimers.remove(sessionId);
      final bytes = _pendingBytes.remove(sessionId);
      if (bytes != null) {
        _updateSession(sessionId, (s) => s.copyWith(bytesTransferred: bytes));
      }
    });
  }

  void _flushProgress(String sessionId) {
    _progressTimers[sessionId]?.cancel();
    _progressTimers.remove(sessionId);
    final bytes = _pendingBytes.remove(sessionId);
    if (bytes != null) {
      _updateSession(sessionId, (s) => s.copyWith(bytesTransferred: bytes));
    }
  }

  void _updateSession(
    String sessionId,
    TransferSession Function(TransferSession) updater,
  ) {
    state = [
      for (final s in state)
        if (s.sessionId == sessionId) updater(s) else s,
    ];
  }
}

/// One file inside a batched quick-send.
class QuickOutgoingFile {
  final String filePath;
  final String fileName;
  final int fileSize;
  final String? fileMimeType;

  QuickOutgoingFile({
    required this.filePath,
    required this.fileName,
    required this.fileSize,
    this.fileMimeType,
  });
}

class _AcceptedQuickSession {
  final String sessionId;
  final String token;
  final String fileName;
  final int fileSize;
  final String senderId;
  final String senderAlias;
  final String? fileMimeType;

  _AcceptedQuickSession({
    required this.sessionId,
    required this.token,
    required this.fileName,
    required this.fileSize,
    required this.senderId,
    required this.senderAlias,
    this.fileMimeType,
  });
}

class _ActiveQuickSend {
  final CancelToken cancelToken;
  final String remoteSessionId;
  final String targetIp;
  final int targetPort;

  _ActiveQuickSend({
    required this.cancelToken,
    required this.remoteSessionId,
    required this.targetIp,
    required this.targetPort,
  });
}

class _QuickReceiverCancelled implements Exception {
  @override
  String toString() => 'Receiver cancelled quick transfer';
}

class _QuickRetryInfo {
  final String targetIp;
  final int targetPort;
  final String targetAlias;

  _QuickRetryInfo({
    required this.targetIp,
    required this.targetPort,
    required this.targetAlias,
  });
}
