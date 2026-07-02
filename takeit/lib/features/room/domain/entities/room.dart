import 'package:freezed_annotation/freezed_annotation.dart';
import 'room_member.dart';

part 'room.freezed.dart';

@freezed
class Room with _$Room {
  const factory Room({
    required String id,
    required String hostFingerprint,
    required List<RoomMember> members,
    required DateTime createdAt,
  }) = _Room;
}
