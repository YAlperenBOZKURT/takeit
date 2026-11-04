import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/transfer_queue_service.dart';
import '../../../clipboard/presentation/providers/clipboard_provider.dart';
import '../../../clipboard/presentation/widgets/clipboard_popup.dart';
import '../../../quick_send/presentation/providers/quick_send_provider.dart';
import '../../../quick_send/presentation/widgets/quick_text_popup.dart';
import '../../../room/presentation/pages/room_invite_sheet.dart';
import '../../../room/presentation/providers/room_provider.dart';
import '../../../transfer/presentation/widgets/transfer_approval_sheet.dart';
import '../pages/home_shell.dart';

/// The one place that shows incoming requests — room invites, transfer
/// approvals, shared clipboard and quick texts — one at a time, in that
/// order of priority.
///
/// Every tab used to run its own copy of this queue. The tabs stay mounted
/// in the shell's IndexedStack, so each request was opened by every tab that
/// had been visited (stacked sheets), and after an accept no tab looked at
/// the queue again, leaving the remaining invites hidden until the next one
/// arrived.
class IncomingPopupHost extends ConsumerStatefulWidget {
  final Widget child;

  const IncomingPopupHost({super.key, required this.child});

  @override
  ConsumerState<IncomingPopupHost> createState() => _IncomingPopupHostState();
}

class _IncomingPopupHostState extends ConsumerState<IncomingPopupHost> {
  /// Whether a popup is on screen; the next one waits until it closes.
  bool _showing = false;

  @override
  void initState() {
    super.initState();
    // Requests that arrived before the shell was built.
    WidgetsBinding.instance.addPostFrameCallback((_) => _showNext());
  }

  void _showNext() {
    if (!mounted || _showing) return;

    final invites = ref.read(roomInvitesProvider);
    if (invites.isNotEmpty) {
      _present(_showInvite(invites.last));
      return;
    }

    final approval = ref.read(currentApprovalProvider);
    if (approval != null) {
      _present(
        showModalBottomSheet<void>(
          context: context,
          isDismissible: false,
          builder: (_) => TransferApprovalSheet(batch: approval),
        ),
      );
      return;
    }

    final clipboard = ref.read(incomingClipboardProvider);
    if (clipboard != null) {
      ref.read(incomingClipboardProvider.notifier).state = null;
      _present(
        showDialog<void>(
          context: context,
          builder: (_) => ClipboardPopup(
            senderAlias: clipboard['senderAlias'] as String? ?? 'Someone',
            content: clipboard['content'] as String? ?? '',
          ),
        ),
      );
      return;
    }

    final quickText = ref.read(incomingQuickTextProvider);
    if (quickText != null) {
      ref.read(incomingQuickTextProvider.notifier).state = null;
      _present(
        showDialog<void>(
          context: context,
          builder: (_) => QuickTextPopup(message: quickText),
        ),
      );
    }
  }

  /// Marks a popup as showing until [closed] completes, then moves on.
  void _present(Future<void> closed) {
    _showing = true;
    closed.whenComplete(() {
      _showing = false;
      // Next frame, so the closing route is gone before another opens.
      WidgetsBinding.instance.addPostFrameCallback((_) => _showNext());
    });
  }

  Future<void> _showInvite(Map<String, dynamic> invite) async {
    final accepted = await showModalBottomSheet<bool>(
      context: context,
      isDismissible: false,
      builder: (_) => RoomInviteSheet(invite: invite),
    );
    if (!mounted) return;

    if (accepted == true) {
      ref.read(homeTabProvider.notifier).state = 1;
      return;
    }
    // Swiped down or closed with Back, without picking Join or Decline:
    // that is a decline. Left in the queue it would reopen immediately.
    final stillQueued = ref
        .read(roomInvitesProvider)
        .any((i) => i['roomId'] == invite['roomId']);
    if (accepted == null && stillQueued) {
      ref.read(roomProvider.notifier).declineInvite(invite);
    }
  }

  @override
  Widget build(BuildContext context) {
    // React to any change, not only to the queue growing: a newer invite
    // from the same host replaces the old one without changing the length.
    ref.listen(roomInvitesProvider, (_, next) {
      if (next.isNotEmpty) _showNext();
    });
    ref.listen(currentApprovalProvider, (_, next) {
      if (next != null) _showNext();
    });
    ref.listen(incomingClipboardProvider, (_, next) {
      if (next != null) _showNext();
    });
    ref.listen(incomingQuickTextProvider, (_, next) {
      if (next != null) _showNext();
    });
    return widget.child;
  }
}
