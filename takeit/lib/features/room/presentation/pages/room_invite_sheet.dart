import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/l10n/app_strings.dart';
import '../providers/room_provider.dart';
import '../utils/room_switch_guard.dart';

class RoomInviteSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic> invite;

  const RoomInviteSheet({super.key, required this.invite});

  @override
  ConsumerState<RoomInviteSheet> createState() => _RoomInviteSheetState();
}

class _RoomInviteSheetState extends ConsumerState<RoomInviteSheet> {
  bool _acting = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = AppStrings.of(context);
    final invite = widget.invite;
    final hostAlias = invite['hostAlias'] as String? ?? 'Someone';
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;

    // Auto-dismiss if this invite was removed (e.g., sender went offline).
    // Skip when the user is actively accepting/declining to avoid double-pop.
    final invites = ref.watch(roomInvitesProvider);
    final hostFp = invite['hostFingerprint'] as String?;
    final stillQueued = invites.any((i) => i['hostFingerprint'] == hostFp);
    if (!stillQueued && !_acting) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop(false);
      });
    }

    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: 24 + bottomPadding,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.3,
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Icon(Icons.group_add, size: 48, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              s.roomInvite,
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              s.invitesYou(hostAlias),
              style: theme.textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: () async {
                setState(() => _acting = true);
                final ok = await confirmRoomSwitch(context, ref);
                if (!ok) {
                  if (mounted) setState(() => _acting = false);
                  return;
                }
                if (!context.mounted) return;
                ref.read(roomProvider.notifier).acceptInvite(invite);
                if (context.mounted) Navigator.of(context).pop(true);
              },
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: const Icon(Icons.check),
              label: Text(s.join),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () {
                setState(() => _acting = true);
                ref.read(roomProvider.notifier).declineInvite(invite);
                Navigator.of(context).pop(false);
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: const Icon(Icons.close),
              label: Text(s.decline),
            ),
          ],
        ),
      ),
    );
  }
}
