import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/l10n/app_strings.dart';
import '../../domain/entities/room_member.dart';
import '../providers/room_provider.dart';

/// If the user is in a room, prompt to confirm switching.
/// Returns true if there's no room, or user confirms. False if cancelled.
Future<bool> confirmRoomSwitch(BuildContext context, WidgetRef ref) async {
  final room = ref.read(roomProvider);
  if (room == null) return true;

  final s = AppStrings.of(context);
  final members = room.members
      .where((m) => m.status == MemberStatus.accepted)
      .map((m) => m.alias)
      .join(', ');

  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(s.switchRoomTitle),
      content: Text(s.switchRoomMsg(members)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(s.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(s.switchRoom),
        ),
      ],
    ),
  );
  return result ?? false;
}
