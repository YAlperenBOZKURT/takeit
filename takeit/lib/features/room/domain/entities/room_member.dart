import 'package:freezed_annotation/freezed_annotation.dart';

part 'room_member.freezed.dart';

enum MemberStatus { pending, accepted, declined, offline }

@freezed
class RoomMember with _$RoomMember {
  const factory RoomMember({
    required String fingerprint,
    required String alias,
    required String ip,
    required int port,
    required String deviceType,
    @Default(MemberStatus.pending) MemberStatus status,
  }) = _RoomMember;
}
