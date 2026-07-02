import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:uuid/uuid.dart';
import '../../../../core/network/http_client.dart';
import '../../../../core/network/request_origin.dart';
import '../../../../main.dart';
import '../../../chat/domain/entities/message.dart';
import '../../../chat/presentation/providers/chat_provider.dart';
import '../../../discovery/presentation/providers/discovery_provider.dart';
import '../../../history/presentation/providers/history_provider.dart';
import '../../../nickname/presentation/providers/nickname_provider.dart';
import '../../../room/domain/entities/room_member.dart';
import '../../../room/presentation/providers/room_provider.dart';

/// Holds the latest incoming clipboard content for popup display.
final incomingClipboardProvider = StateProvider<Map<String, dynamic>?>(
  (ref) => null,
);

final clipboardProvider = Provider<ClipboardNotifier>((ref) {
  return ClipboardNotifier(ref);
});

class ClipboardNotifier {
  final Ref _ref;
  final Dio _client = createHttpClient();

  ClipboardNotifier(this._ref) {
    _registerHandler();
  }

  void _registerHandler() {
    final server = _ref.read(httpServerProvider);
    server.registerHandler('/api/takeit/v1/clipboard', _handleClipboard);
  }

  Future<shelf.Response> _handleClipboard(shelf.Request request) async {
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
      final data = body as Map<String, dynamic>;
      _ref.read(incomingClipboardProvider.notifier).state = data;

      final senderAlias = data['senderAlias'] as String? ?? '';
      final content = data['content'] as String? ?? '';
      _ref
          .read(historyProvider.notifier)
          .addRecord(
            fileName: content.length > 50
                ? '${content.substring(0, 50)}...'
                : content,
            fileSize: content.length,
            peerAlias: senderAlias,
            direction: 'clipboard_received',
            fileMimeType: 'text/clipboard',
            savePath: content,
          );

      final message = Message(
        id: const Uuid().v4(),
        roomId: room.id,
        senderId: data['senderId'] as String? ?? '',
        senderAlias: data['senderAlias'] as String? ?? '',
        content: data['content'] as String? ?? '',
        timestamp: DateTime.now(),
        type: MessageType.clipboard,
      );
      _ref.read(chatProvider.notifier).addMessage(message);
    } catch (e) {
      debugPrint('Failed to parse clipboard: $e');
      return shelf.Response.internalServerError();
    }
    return shelf.Response.ok(
      jsonEncode({'status': 'ok'}),
      headers: {'Content-Type': 'application/json'},
    );
  }

  /// Returns true if clipboard was shared, false if empty/no room.
  Future<bool> shareClipboard() async {
    final room = _ref.read(roomProvider);
    if (room == null) return false;

    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data == null || data.text == null || data.text!.trim().isEmpty) {
      return false;
    }

    final fingerprint = _ref.read(fingerprintProvider);
    final alias = _ref.read(nicknameProvider);

    final clipboardText = data.text!;
    final payload = {
      'senderAlias': alias,
      'senderId': fingerprint,
      'content': clipboardText,
    };

    final message = Message(
      id: const Uuid().v4(),
      roomId: room.id,
      senderId: fingerprint,
      senderAlias: alias,
      content: clipboardText,
      timestamp: DateTime.now(),
      type: MessageType.clipboard,
    );
    _ref.read(chatProvider.notifier).addMessage(message);

    final members = room.members
        .where((m) => m.status == MemberStatus.accepted)
        .toList();

    for (final member in members) {
      try {
        await _client.post(
          'http://${member.ip}:${member.port}/api/takeit/v1/clipboard',
          data: payload,
        );
      } catch (e) {
        debugPrint('Failed to send clipboard to ${member.alias}: $e');
      }
    }

    final peerNames = members.map((m) => m.alias).join(', ');
    _ref
        .read(historyProvider.notifier)
        .addRecord(
          fileName: clipboardText.length > 50
              ? '${clipboardText.substring(0, 50)}...'
              : clipboardText,
          fileSize: clipboardText.length,
          peerAlias: peerNames,
          direction: 'clipboard_sent',
          fileMimeType: 'text/clipboard',
          savePath: clipboardText,
        );

    return true;
  }
}
