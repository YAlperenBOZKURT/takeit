import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/network/http_client.dart';
import '../../../room/domain/entities/room_member.dart';
import '../entities/message.dart';

class SendMessage {
  final Dio _client = createHttpClient();

  Future<void> call(Message message, List<RoomMember> members) async {
    final payload = message.toJson();

    final futures = members
        .where((m) => m.status == MemberStatus.accepted)
        .map((member) => _sendTo(member, payload));

    await Future.wait(futures);
  }

  Future<void> _sendTo(RoomMember member, Map<String, dynamic> payload) async {
    try {
      await _client.post(
        'http://${member.ip}:${member.port}/api/takeit/v1/message',
        data: payload,
      );
    } catch (e) {
      debugPrint('Failed to send message to ${member.alias}: $e');
    }
  }
}
