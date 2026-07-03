import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:shelf/shelf.dart' as shelf;
import '../../../../core/network/http_client.dart';
import '../../../../core/network/http_server.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/services/transfer_keep_alive.dart';
import '../../../../core/services/transfer_queue_service.dart';
import '../../../../core/services/window_alert_service.dart';
import '../../../../main.dart';
import '../../../discovery/presentation/providers/discovery_provider.dart';
import '../../../nickname/presentation/providers/nickname_provider.dart';
import '../../../room/domain/entities/room_member.dart';
import '../../../room/presentation/providers/room_provider.dart';
import '../../../chat/domain/entities/message.dart';
import '../../../chat/presentation/providers/chat_provider.dart';
import '../../../history/presentation/providers/history_provider.dart';
import '../../../../core/services/background_transfer_service.dart';
import '../../../settings/presentation/providers/settings_provider.dart';
import '../../data/services/file_transfer_service.dart';
import '../../domain/entities/transfer_session.dart';
import 'package:dio/dio.dart';

/// Whether a send operation is currently in progress (blocks new sends).
final isSendingProvider = StateProvider<bool>((ref) => false);

final transferProvider =
    StateNotifierProvider<TransferNotifier, List<TransferSession>>((ref) {
      return TransferNotifier(ref);
    });

/// Stores savePaths for received files, keyed by "senderId:fileName".
/// Used to link chat fileMeta messages to downloaded files.
final receivedFilePathsProvider = StateProvider<Map<String, String>>(
  (ref) => {},
);

class TransferNotifier extends StateNotifier<List<TransferSession>> {
  final Ref _ref;
  final FileTransferService _service = FileTransferService();
  final Dio _client = createHttpClient();

  /// Cached at construction — dispose() must not call _ref.read().
  late final AppHttpServer _server = _ref.read(httpServerProvider);

  /// Accepted sessions waiting for upload (sessionId → metadata).
  final Map<String, _AcceptedSession> _acceptedSessions = {};

  /// Active outgoing sends, keyed by local sessionId.
  final Map<String, _ActiveSend> _activeSends = {};

  /// Retry info for failed outgoing sends, keyed by local sessionId.
  final Map<String, _RetryInfo> _retryInfos = {};

  /// Outgoing batches awaiting recipient approval.
  final List<_PendingBatchSend> _pendingBatchSends = [];

  /// Throttle timers for progress updates — avoids creating a new list for every chunk.
  final Map<String, Timer?> _progressTimers = {};
  final Map<String, int> _pendingBytes = {};

  TransferNotifier(this._ref) : super([]) {
    _registerHandlers();
  }

  @override
  void dispose() {
    _server.unregisterHandler('/api/takeit/v1/transfer/prepare-batch');
    _server.unregisterHandler('/api/takeit/v1/transfer/upload');
    _server.unregisterHandler('/api/takeit/v1/transfer/cancel');
    _server.unregisterHandler('/api/takeit/v1/transfer/cancel-batch');
    for (final t in _progressTimers.values) {
      t?.cancel();
    }
    super.dispose();
  }

  void _registerHandlers() {
    _server.registerHandler(
      '/api/takeit/v1/transfer/prepare-batch',
      _handlePrepareBatch,
    );
    _server.registerHandler('/api/takeit/v1/transfer/upload', _handleUpload);
    _server.registerHandler('/api/takeit/v1/transfer/cancel', _handleCancel);
    _server.registerHandler(
      '/api/takeit/v1/transfer/cancel-batch',
      _handleCancelBatch,
    );
  }

  Future<shelf.Response> _handleCancelBatch(shelf.Request request) async {
    final body = jsonDecode(await request.readAsString());
    final batchId = body['batchId'] as String?;
    if (batchId != null) {
      _ref.read(transferQueueProvider).cancelBatch(batchId);
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
            ..fileId = const Uuid().v4()
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
      source: TransferSource.room,
      files: batchedFiles,
      approvalCompleter: Completer<List<bool>>(),
    );

    final results = await queue.enqueueBatch(batch);

    // Register accepted sessions for upload handler
    final responseFiles = <Map<String, dynamic>>[];
    for (var i = 0; i < batchedFiles.length; i++) {
      final bf = batchedFiles[i];
      final accepted = i < results.length && results[i];
      final entry = <String, dynamic>{'index': i, 'accepted': accepted};
      if (accepted) {
        _acceptedSessions[bf.sessionId!] = _AcceptedSession(
          sessionId: bf.sessionId!,
          fileId: bf.fileId!,
          token: bf.token!,
          fileName: bf.fileName,
          fileSize: bf.fileSize,
          senderId: senderId,
          senderAlias: senderAlias,
          fileMimeType: bf.fileMimeType,
        );
        entry['sessionId'] = bf.sessionId;
        entry['fileId'] = bf.fileId;
        entry['token'] = bf.token;

        final sid = bf.sessionId!;
        Timer(const Duration(seconds: 120), () {
          if (_acceptedSessions.remove(sid) != null) {
            debugPrint('Accepted session $sid expired without upload');
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

    // Look up accepted session (keep it until upload fully completes)
    final accepted = _acceptedSessions[sessionId];
    if (accepted == null || accepted.token != token) {
      return shelf.Response.forbidden('Invalid session or token');
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
      fileId: accepted.fileId,
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
    state = [...state, session];
    _syncKeepAlive();

    IOSink? sink;
    var bytesReceived = 0;
    final receiveStartedAt = DateTime.now();
    try {
      final file = File(savePath);
      sink = file.openWrite();
      var bytesSinceFlush = 0;

      debugPrint(
        'Receiving ${accepted.fileName} (${accepted.fileSize} bytes) '
        '→ $savePath',
      );

      // Stall detection must live on the stream itself: a check inside the
      // loop body only runs when a chunk arrives, so it can never catch a
      // stream that goes silent (and would kill one that recovers).
      final body = request.read().timeout(
        kReceiveStallTimeout,
        onTimeout: (eventSink) => eventSink.addError(
          TimeoutException(
            'No data received for ${kReceiveStallTimeout.inSeconds}s — '
            'sender disconnected',
          ),
        ),
      );

      await for (final chunk in body) {
        // Check if user cancelled on this side
        final current = state
            .where((s) => s.sessionId == sessionId)
            .firstOrNull;
        if (current?.status == TransferStatus.cancelled) {
          throw _ReceiverCancelled();
        }

        sink.add(chunk);
        bytesReceived += chunk.length;
        bytesSinceFlush += chunk.length;
        // Bound IOSink buffering: without this, a disk slower than the
        // network lets the in-memory write buffer grow without limit.
        if (bytesSinceFlush >= kReceiveFlushBytes) {
          await sink.flush().timeout(kWriteStallTimeout);
          bytesSinceFlush = 0;
        }
        _updateProgress(sessionId, bytesReceived);
      }

      await sink.flush().timeout(kWriteStallTimeout);
      await sink.close().timeout(kWriteStallTimeout);
      sink = null;

      // Reject truncated/over-long transfers instead of reporting success.
      if (bytesReceived != accepted.fileSize) {
        throw Exception(
          'Incomplete transfer: received $bytesReceived of '
          '${accepted.fileSize} bytes',
        );
      }

      debugPrint(
        'Received ${accepted.fileName}: $bytesReceived bytes in '
        '${DateTime.now().difference(receiveStartedAt).inSeconds}s',
      );

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

      final key = '${accepted.senderId}:${accepted.fileName}';
      final paths = Map<String, String>.from(
        _ref.read(receivedFilePathsProvider),
      );
      paths[key] = savePath;
      _ref.read(receivedFilePathsProvider.notifier).state = paths;

      _updateChatFileSavePath(accepted.fileName, savePath, accepted.senderId);

      _acceptedSessions.remove(sessionId);

      return shelf.Response.ok(
        jsonEncode({'status': 'completed'}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      debugPrint(
        'Upload receive error for ${accepted.fileName} after '
        '$bytesReceived/${accepted.fileSize} bytes '
        '(${DateTime.now().difference(receiveStartedAt).inSeconds}s): $e',
      );
      final isCancel = e is _ReceiverCancelled;
      _flushProgress(sessionId);
      _updateSession(
        sessionId,
        (s) => s.copyWith(
          status: isCancel ? TransferStatus.cancelled : TransferStatus.failed,
        ),
      );
      queue.downloadFailed(sessionId, reason: e.toString());
      _acceptedSessions.remove(sessionId);

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

  // ─── Sender side ───

  bool get isSending => _ref.read(isSendingProvider);

  Future<void> sendFile({
    required String filePath,
    required String fileName,
    required int fileSize,
    String? fileMimeType,
  }) {
    return sendFiles([
      OutgoingFile(
        filePath: filePath,
        fileName: fileName,
        fileSize: fileSize,
        fileMimeType: fileMimeType,
      ),
    ]);
  }

  Future<void> sendFiles(List<OutgoingFile> files) async {
    if (files.isEmpty) return;
    if (_ref.read(isSendingProvider)) return;
    _ref.read(isSendingProvider.notifier).state = true;

    try {
      final room = _ref.read(roomProvider);
      if (room == null) return;

      final fingerprint = _ref.read(fingerprintProvider);
      final alias = _ref.read(nicknameProvider);

      final acceptedMembers = room.members
          .where((m) => m.status == MemberStatus.accepted)
          .toList();

      final futures = acceptedMembers.map((member) async {
        await _sendBatchToMember(
          member: member,
          files: files,
          fingerprint: fingerprint,
          alias: alias,
        );
      });

      await Future.wait(futures);

      // Post file meta to chat once per file (not per member).
      for (final f in files) {
        _postFileMetaToChat(
          f.fileName,
          f.fileSize,
          f.fileMimeType,
          savePath: f.filePath,
        );
      }
    } finally {
      _ref.read(isSendingProvider.notifier).state = false;
    }
  }

  Future<void> _sendBatchToMember({
    required RoomMember member,
    required List<OutgoingFile> files,
    required String fingerprint,
    required String alias,
    String? batchId,
  }) async {
    // One local session per file so the UI shows each one individually.
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
    _syncKeepAlive();

    List<dynamic>? results;
    final bId = batchId ?? const Uuid().v4();
    _pendingBatchSends.add(
      _PendingBatchSend(batchId: bId, ip: member.ip, port: member.port),
    );
    try {
      final response = await _client.post(
        'http://${member.ip}:${member.port}/api/takeit/v1/transfer/prepare-batch',
        data: {
          'batchId': bId,
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
        options: Options(receiveTimeout: const Duration(seconds: 60)),
      );

      if (response.statusCode != 200) {
        for (final sid in localSessionIds) {
          _updateSession(
            sid,
            (s) => s.copyWith(status: TransferStatus.declined),
          );
        }
        return;
      }
      results = (response.data as Map<String, dynamic>)['files'] as List;
      _pendingBatchSends.removeWhere(
        (p) => p.batchId == bId && p.ip == member.ip && p.port == member.port,
      );
    } catch (e) {
      _pendingBatchSends.removeWhere(
        (p) => p.batchId == bId && p.ip == member.ip && p.port == member.port,
      );
      debugPrint('Prepare-batch to ${member.alias} failed: $e');
      for (var i = 0; i < localSessionIds.length; i++) {
        _updateSession(
          localSessionIds[i],
          (s) => s.copyWith(status: TransferStatus.failed),
        );
        _retryInfos[localSessionIds[i]] = _RetryInfo(
          targetIp: member.ip,
          targetPort: member.port,
        );
      }
      return;
    }

    // Upload each accepted file sequentially (global queue is single-slot anyway).
    for (var i = 0; i < files.length; i++) {
      final sid = localSessionIds[i];
      final f = files[i];
      final entry = i < results.length
          ? results[i] as Map<String, dynamic>
          : null;
      final accepted = entry != null && entry['accepted'] == true;

      if (!accepted) {
        _updateSession(sid, (s) => s.copyWith(status: TransferStatus.declined));
        continue;
      }

      await _uploadOneFile(
        localSessionId: sid,
        member: member,
        file: f,
        remoteSessionId: entry['sessionId'] as String,
        fileId: entry['fileId'] as String,
        token: entry['token'] as String,
      );
    }
  }

  Future<void> _uploadOneFile({
    required String localSessionId,
    required RoomMember member,
    required OutgoingFile file,
    required String remoteSessionId,
    required String fileId,
    required String token,
  }) async {
    // Guard: user may have cancelled before we register the active send.
    final preCheck = state
        .where((s) => s.sessionId == localSessionId)
        .firstOrNull;
    if (preCheck?.status == TransferStatus.cancelled) return;

    final cancelToken = CancelToken();
    _activeSends[localSessionId] = _ActiveSend(
      cancelToken: cancelToken,
      remoteSessionId: remoteSessionId,
      targetIp: member.ip,
      targetPort: member.port,
    );

    _updateSession(
      localSessionId,
      (s) => s.copyWith(
        status: TransferStatus.inProgress,
        fileId: fileId,
        startedAt: DateTime.now(),
      ),
    );

    try {
      await _service.sendFile(
        targetIp: member.ip,
        targetPort: member.port,
        filePath: file.filePath,
        sessionId: remoteSessionId,
        fileId: fileId,
        token: token,
        cancelToken: cancelToken,
        onProgress: (sent, total) {
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
            peerAlias: member.alias,
            direction: 'sent',
            fileMimeType: file.fileMimeType,
            savePath: file.filePath,
          );
    } catch (e) {
      debugPrint('Upload ${file.fileName} to ${member.alias} failed: $e');
      _flushProgress(localSessionId);
      final currentStatus = state
          .where((s) => s.sessionId == localSessionId)
          .map((s) => s.status)
          .firstOrNull;
      if (currentStatus == TransferStatus.cancelled) {
        // Already marked cancelled by user — keep it.
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
        _retryInfos[localSessionId] = _RetryInfo(
          targetIp: member.ip,
          targetPort: member.port,
        );
      }
    } finally {
      _activeSends.remove(localSessionId);
    }
  }

  Future<void> _postFileMetaToChat(
    String fileName,
    int fileSize,
    String? mimeType, {
    String? savePath,
  }) async {
    final room = _ref.read(roomProvider);
    if (room == null) return;
    final fingerprint = _ref.read(fingerprintProvider);
    final alias = _ref.read(nicknameProvider);

    final message = Message(
      id: const Uuid().v4(),
      roomId: room.id,
      senderId: fingerprint,
      senderAlias: alias,
      content: fileName,
      timestamp: DateTime.now(),
      type: MessageType.fileMeta,
      fileName: fileName,
      fileSize: fileSize,
      fileMimeType: mimeType,
      savePath: savePath,
    );

    _ref.read(chatProvider.notifier).addMessage(message);

    final members = room.members.where(
      (m) => m.status == MemberStatus.accepted,
    );
    for (final member in members) {
      try {
        await _client.post(
          'http://${member.ip}:${member.port}/api/takeit/v1/message',
          data: message.toJson(),
        );
      } catch (_) {}
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

    final updated = state.where((s) => s.sessionId == sessionId).firstOrNull;
    if (updated != null && updated.status == TransferStatus.inProgress) {
      final percent = (updated.progress * 100).round();
      BackgroundTransferService.updateProgress(updated.fileName, percent);
    }

    _syncKeepAlive();
  }

  /// Report room-transfer activity to the shared keep-alive (wakelock +
  /// foreground service). Source-scoped so quick-send activity is unaffected.
  void _syncKeepAlive() {
    TransferKeepAlive.setActive(
      'room',
      state.any(
        (s) =>
            s.status == TransferStatus.inProgress ||
            s.status == TransferStatus.pending,
      ),
    );
  }

  /// Throttled progress update — collects bytes and flushes to state max every 100ms.
  /// Prevents creating ~1500 new state lists for a 100MB file.
  void _updateProgress(String sessionId, int bytesTransferred) {
    _pendingBytes[sessionId] = bytesTransferred;
    if (_progressTimers[sessionId] != null) return; // timer already queued
    _progressTimers[sessionId] = Timer(const Duration(milliseconds: 100), () {
      _progressTimers.remove(sessionId);
      final bytes = _pendingBytes.remove(sessionId);
      if (bytes != null) {
        _updateSession(sessionId, (s) => s.copyWith(bytesTransferred: bytes));
      }
    });
  }

  /// Flush any pending throttled progress for a session (call before status change).
  void _flushProgress(String sessionId) {
    _progressTimers[sessionId]?.cancel();
    _progressTimers.remove(sessionId);
    final bytes = _pendingBytes.remove(sessionId);
    if (bytes != null) {
      _updateSession(sessionId, (s) => s.copyWith(bytesTransferred: bytes));
    }
  }

  void _updateChatFileSavePath(
    String fileName,
    String? savePath,
    String senderId,
  ) {
    if (savePath == null) return;
    _ref
        .read(chatProvider.notifier)
        .updateFileSavePath(fileName, savePath, senderId);
  }

  void cancelSession(String sessionId) {
    _updateSession(
      sessionId,
      (s) => s.copyWith(status: TransferStatus.cancelled),
    );

    // If this is an active outgoing send — abort dio + notify peer.
    final active = _activeSends.remove(sessionId);
    if (active != null) {
      if (!active.cancelToken.isCancelled) {
        active.cancelToken.cancel('user_cancelled');
      }
      // Fire-and-forget peer notify so receiver can clean up partial file fast.
      () async {
        try {
          await _client.post(
            'http://${active.targetIp}:${active.targetPort}/api/takeit/v1/transfer/cancel'
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

  /// Ask all recipients still showing an approval popup for our outgoing
  /// batches to dismiss it. Called when the sender leaves the chat/room
  /// before the recipient has responded.
  void cancelPendingSends() {
    if (_pendingBatchSends.isEmpty) return;
    final pending = List<_PendingBatchSend>.from(_pendingBatchSends);
    _pendingBatchSends.clear();
    for (final p in pending) {
      () async {
        try {
          await _client.post(
            'http://${p.ip}:${p.port}/api/takeit/v1/transfer/cancel-batch',
            data: {'batchId': p.batchId},
            options: Options(
              sendTimeout: const Duration(seconds: 3),
              receiveTimeout: const Duration(seconds: 3),
            ),
          );
        } catch (_) {}
      }();
    }
  }

  void clearCompleted() {
    final removing = state
        .where(
          (s) =>
              s.status == TransferStatus.completed ||
              s.status == TransferStatus.failed ||
              s.status == TransferStatus.cancelled ||
              s.status == TransferStatus.declined,
        )
        .map((s) => s.sessionId)
        .toSet();
    _retryInfos.removeWhere((id, _) => removing.contains(id));
    state = state.where((s) => !removing.contains(s.sessionId)).toList();
  }

  /// Retry a failed outgoing send.
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

    final fingerprint = _ref.read(fingerprintProvider);
    final alias = _ref.read(nicknameProvider);

    await _sendBatchToMember(
      member: RoomMember(
        fingerprint: '',
        alias: '',
        ip: retry.targetIp,
        port: retry.targetPort,
        deviceType: '',
        status: MemberStatus.accepted,
      ),
      files: [
        OutgoingFile(
          filePath: filePath,
          fileName: session.fileName,
          fileSize: session.fileSize,
          fileMimeType: session.fileMimeType,
        ),
      ],
      fingerprint: fingerprint,
      alias: alias,
    );
  }

  bool canRetry(String sessionId) {
    return _retryInfos.containsKey(sessionId);
  }
}

/// One file inside a batched outgoing send.
class OutgoingFile {
  final String filePath;
  final String fileName;
  final int fileSize;
  final String? fileMimeType;

  OutgoingFile({
    required this.filePath,
    required this.fileName,
    required this.fileSize,
    this.fileMimeType,
  });
}

class _AcceptedSession {
  final String sessionId;
  final String fileId;
  final String token;
  final String fileName;
  final int fileSize;
  final String senderId;
  final String senderAlias;
  final String? fileMimeType;

  _AcceptedSession({
    required this.sessionId,
    required this.fileId,
    required this.token,
    required this.fileName,
    required this.fileSize,
    required this.senderId,
    required this.senderAlias,
    this.fileMimeType,
  });
}

class _ActiveSend {
  final CancelToken cancelToken;
  final String remoteSessionId;
  final String targetIp;
  final int targetPort;

  _ActiveSend({
    required this.cancelToken,
    required this.remoteSessionId,
    required this.targetIp,
    required this.targetPort,
  });
}

class _ReceiverCancelled implements Exception {
  @override
  String toString() => 'Receiver cancelled transfer';
}

class _RetryInfo {
  final String targetIp;
  final int targetPort;

  _RetryInfo({required this.targetIp, required this.targetPort});
}

class _PendingBatchSend {
  final String batchId;
  final String ip;
  final int port;

  _PendingBatchSend({
    required this.batchId,
    required this.ip,
    required this.port,
  });
}
