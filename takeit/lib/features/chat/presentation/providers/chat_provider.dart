import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:shelf/shelf.dart' as shelf;
import '../../../../core/network/request_origin.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/services/window_alert_service.dart';
import '../../../../main.dart';
import '../../../discovery/presentation/providers/discovery_provider.dart';
import '../../../nickname/presentation/providers/nickname_provider.dart';
import '../../../room/presentation/providers/room_provider.dart';
import '../../../transfer/presentation/providers/transfer_provider.dart';
import '../../domain/entities/message.dart';
import '../../domain/usecases/send_message.dart';

final chatProvider = StateNotifierProvider<ChatNotifier, List<Message>>((ref) {
  return ChatNotifier(ref);
});

class ChatNotifier extends StateNotifier<List<Message>> {
  final Ref _ref;
  final SendMessage _sendMessage = SendMessage();

  ChatNotifier(this._ref) : super([]) {
    _registerHandler();
  }

  void _registerHandler() {
    final server = _ref.read(httpServerProvider);
    server.registerHandler('/api/takeit/v1/message', _handleMessage);
  }

  Future<shelf.Response> _handleMessage(shelf.Request request) async {
    final room = _ref.read(roomProvider);
    if (room == null ||
        !isFromAllowedIp(request, room.members.map((m) => m.ip))) {
      return shelf.Response.forbidden(
        jsonEncode({'error': 'not_a_member'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
    try {
      final body = jsonDecode(await request.readAsString());
      var message = Message.fromJson(body as Map<String, dynamic>);
      // Strip sender's savePath — receiver will get their own after download
      if (message.type == MessageType.fileMeta) {
        // Check if we already downloaded this file (transfer finishes before fileMeta arrives)
        final key = '${message.senderId}:${message.fileName}';
        final receivedPaths = _ref.read(receivedFilePathsProvider);
        final localPath = receivedPaths[key];
        message = message.copyWith(savePath: localPath);
      }
      state = [...state, message];

      final content = message.type == MessageType.text
          ? message.content
          : '📎 Sent a file';
      NotificationService.notifyMessage(message.senderAlias, content);
      if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
        WindowAlertService.flashWindow();
      }
    } catch (e) {
      debugPrint('Failed to parse incoming message: $e');
      return shelf.Response.internalServerError();
    }
    return shelf.Response.ok(
      jsonEncode({'status': 'ok'}),
      headers: {'Content-Type': 'application/json'},
    );
  }

  Future<void> sendTextMessage(String content) async {
    final room = _ref.read(roomProvider);
    if (room == null || content.trim().isEmpty) return;

    final fingerprint = _ref.read(fingerprintProvider);
    final alias = _ref.read(nicknameProvider);

    final message = Message(
      id: const Uuid().v4(),
      roomId: room.id,
      senderId: fingerprint,
      senderAlias: alias,
      content: content.trim(),
      timestamp: DateTime.now(),
    );

    state = [...state, message];

    await _sendMessage(message, room.members);
  }

  void addMessage(Message message) {
    state = [...state, message];
  }

  void updateFileSavePath(String fileName, String savePath, String senderId) {
    final messages = List<Message>.from(state);
    for (var i = messages.length - 1; i >= 0; i--) {
      final m = messages[i];
      if (m.type == MessageType.fileMeta &&
          m.fileName == fileName &&
          m.senderId == senderId &&
          m.savePath == null) {
        messages[i] = m.copyWith(savePath: savePath);
        break;
      }
    }
    state = messages;
  }

  void clearMessages() {
    state = [];
  }
}
