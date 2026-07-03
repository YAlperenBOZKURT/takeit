import 'dart:io';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/l10n/app_strings.dart';
import '../../../home/presentation/pages/home_shell.dart';
import '../../../clipboard/presentation/providers/clipboard_provider.dart';
import '../../../clipboard/presentation/widgets/clipboard_popup.dart';
import '../../../discovery/presentation/providers/discovery_provider.dart';
import '../../../room/domain/entities/room_member.dart';
import '../../../room/presentation/providers/room_provider.dart';
import '../../../../core/services/transfer_queue_service.dart';
import '../../../transfer/presentation/providers/transfer_provider.dart';
import '../../../transfer/presentation/widgets/transfer_approval_sheet.dart';
import '../../domain/entities/message.dart';
import '../providers/chat_provider.dart';
import '../../../quick_send/presentation/providers/quick_send_provider.dart';
import '../../../quick_send/presentation/widgets/quick_text_popup.dart';
import '../../../room/presentation/pages/room_invite_sheet.dart';
import '../widgets/chat_input_bar.dart';
import '../widgets/clipboard_bubble.dart';
import '../widgets/file_bubble.dart';
import '../widgets/message_bubble.dart';
import '../../../transfer/domain/entities/transfer_session.dart';
import '../../../transfer/presentation/providers/session_transfers_provider.dart';
import '../../../transfer/presentation/widgets/transfers_fab.dart';

class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({super.key});

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final _scrollController = ScrollController();
  bool _isNearBottom = true;
  bool _isDragging = false;
  final _notifiedIds = <String>{};

  /// Single-popup mutex. Priority: invite > approval > quickText/clipboard.
  String? _activePopup;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  void deactivate() {
    ref.read(transferProvider.notifier).cancelPendingSends();
    super.deactivate();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    _isNearBottom = pos.pixels >= pos.maxScrollExtent - 150;
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final room = ref.watch(roomProvider);
    final messages = ref.watch(chatProvider);
    final fingerprint = ref.watch(fingerprintProvider);
    final theme = Theme.of(context);

    // Navigate back if room is dissolved — but only pull the user away from
    // the Chat tab; don't yank them off another tab they're viewing.
    ref.listen(roomProvider, (prev, next) {
      if (prev != null && next == null && mounted) {
        ref.read(chatProvider.notifier).clearMessages();
        if (ref.read(homeTabProvider) == 1) {
          ref.read(homeTabProvider.notifier).state = 0;
        }
      }
    });

    // Scroll to bottom on new messages (only if user is near bottom)
    ref.listen(chatProvider, (prev, next) {
      if (next.length > (prev?.length ?? 0) && _isNearBottom) {
        _scrollToBottom();
      }
    });

    // Show toast on transfer decline / failure
    ref.listen(sessionTransfersProvider, (prev, next) {
      if (!mounted) return;
      for (final t in next) {
        if (_notifiedIds.contains(t.sessionId)) continue;
        if (t.isFailed) {
          _notifiedIds.add(t.sessionId);
          _showTransferToast(t);
        }
      }
    });

    // Listen for connection warnings
    ref.listen(connectionWarningProvider, (prev, next) {
      if (next != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.wifi_off, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(next)),
              ],
            ),
            backgroundColor: const Color(0xFFE67E22),
            duration: const Duration(seconds: 4),
          ),
        );
        ref.read(connectionWarningProvider.notifier).state = null;
      }
    });

    // Listen for incoming room invites (while in chat)
    ref.listen(roomInvitesProvider, (prev, next) {
      if (next.length > (prev?.length ?? 0)) _checkPopupQueue();
    });

    // Listen for incoming file transfer requests (global queue)
    ref.listen(currentApprovalProvider, (prev, next) {
      if (next != null) _checkPopupQueue();
    });

    // Listen for incoming clipboard
    ref.listen(incomingClipboardProvider, (prev, next) {
      if (next != null) _checkPopupQueue();
    });

    // Listen for incoming quick text
    ref.listen(incomingQuickTextProvider, (prev, next) {
      if (next != null) _checkPopupQueue();
    });

    if (room == null) {
      final noRoomS = AppStrings.of(context);
      return Scaffold(
        appBar: AppBar(title: Text(noRoomS.chat)),
        body: Center(child: Text(noRoomS.noActiveRoom)),
      );
    }

    final acceptedMembers = room.members
        .where((m) => m.status == MemberStatus.accepted)
        .toList();

    final s = AppStrings.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: s.nearbyDevices,
          onPressed: () => ref.read(homeTabProvider.notifier).state = 0,
        ),
        title: Row(
          children: [
            _MemberAvatars(members: room.members),
            const SizedBox(width: 12),
            Text(
              '${acceptedMembers.length + 1} online',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            tooltip: s.leaveRoom,
            onPressed: _confirmLeaveRoom,
          ),
        ],
      ),
      body: DropTarget(
        // Guarded to this tab only — see the matching comment in
        // DeviceListPage._wrapWithDropTarget for why (IndexedStack keeps
        // every tab's DropTarget mounted, so an unguarded drop fires all of
        // them at once).
        onDragEntered: (_) {
          if (ref.read(homeTabProvider) != 1) return;
          setState(() => _isDragging = true);
        },
        onDragExited: (_) => setState(() => _isDragging = false),
        onDragDone: (details) {
          if (ref.read(homeTabProvider) != 1) return;
          setState(() => _isDragging = false);
          _handleDroppedFiles(details);
        },
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(
                  child: messages.isEmpty
                      ? Center(
                          child: Text(
                            s.noMessages,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: messages.length,
                          itemBuilder: (context, index) {
                            final message = messages[index];
                            final isMine = message.senderId == fingerprint;

                            if (message.type == MessageType.fileMeta) {
                              return FileBubble(
                                message: message,
                                isMine: isMine,
                              );
                            }
                            if (message.type == MessageType.clipboard) {
                              return ClipboardBubble(
                                message: message,
                                isMine: isMine,
                              );
                            }
                            return MessageBubble(
                              message: message,
                              isMine: isMine,
                            );
                          },
                        ),
                ),
                ChatInputBar(
                  onSendText: (text) {
                    ref.read(chatProvider.notifier).sendTextMessage(text);
                  },
                  onAttachmentTap: _pickFile,
                  onPasteTap: _shareClipboard,
                  isSending:
                      ref.watch(filePickerBusyProvider) ||
                      ref.watch(isSendingProvider),
                ),
              ],
            ),
            const Positioned(
              right: 16,
              bottom: 80,
              child: SafeArea(child: TransfersFab()),
            ),
            // Drag overlay
            if (_isDragging)
              Positioned.fill(
                child: Container(
                  color: theme.colorScheme.primary.withValues(alpha: 0.15),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 24,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: theme.colorScheme.primary,
                          width: 2,
                          strokeAlign: BorderSide.strokeAlignOutside,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.file_upload_outlined,
                            size: 48,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            s.dropFilesHere,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showTransferToast(SessionTransferView t) {
    if (!mounted) return;
    final s = AppStrings.of(context);
    final isDeclined = t.session.status == TransferStatus.declined;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isDeclined ? Icons.block_rounded : Icons.error_outline,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isDeclined ? s.transferDeclinedToast : s.transferFailedToast,
              ),
            ),
          ],
        ),
        backgroundColor: isDeclined
            ? const Color(0xFFEF4444)
            : const Color(0xFFE67E22),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _handleDroppedFiles(DropDoneDetails details) {
    final batch = <OutgoingFile>[];
    for (final xFile in details.files) {
      if (batch.length >= 10) break;
      final path = xFile.path;
      final file = File(path);
      if (!file.existsSync()) continue;
      batch.add(
        OutgoingFile(
          filePath: path,
          fileName: xFile.name,
          fileSize: file.lengthSync(),
          fileMimeType: _guessMimeType(xFile.name),
        ),
      );
    }
    if (batch.isEmpty) return;
    if (details.files.length > 10 && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Max 10')));
    }
    ref.read(transferProvider.notifier).sendFiles(batch);
  }

  Future<void> _shareClipboard() async {
    final s = AppStrings.of(context);
    final sent = await ref.read(clipboardProvider).shareClipboard();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(sent ? s.clipboardShared : s.clipboardEmpty),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _pickFile() async {
    // Shared with Send and Quick Send: the native picker can only run one
    // invocation at a time across the OS, so a pick already in flight on
    // another surface must block this one instead of racing it.
    if (ref.read(filePickerBusyProvider)) return;
    ref.read(filePickerBusyProvider.notifier).state = true;

    FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(allowMultiple: true);
    } finally {
      ref.read(filePickerBusyProvider.notifier).state = false;
    }
    if (result == null || result.files.isEmpty) return;

    final batch = <OutgoingFile>[];
    for (final file in result.files) {
      if (batch.length >= 10) break;
      if (file.path == null) continue;
      batch.add(
        OutgoingFile(
          filePath: file.path!,
          fileName: file.name,
          fileSize: file.size,
          fileMimeType: _guessMimeType(file.name),
        ),
      );
    }
    if (batch.isEmpty) return;
    if (result.files.length > 10 && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Max 10')));
    }
    ref.read(transferProvider.notifier).sendFiles(batch);
  }

  String? _guessMimeType(String name) {
    final ext = name.split('.').last.toLowerCase();
    return switch (ext) {
      'pdf' => 'application/pdf',
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'gif' => 'image/gif',
      'mp4' => 'video/mp4',
      'mp3' => 'audio/mpeg',
      'zip' => 'application/zip',
      'doc' || 'docx' => 'application/msword',
      'txt' => 'text/plain',
      _ => null,
    };
  }

  void _showClipboardPopup(Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (_) => ClipboardPopup(
        senderAlias: data['senderAlias'] as String? ?? 'Someone',
        content: data['content'] as String? ?? '',
      ),
    );
  }

  void _showTransferApproval(TransferBatch batch) {
    _activePopup = 'approval';
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      builder: (_) => TransferApprovalSheet(batch: batch),
    ).then((_) {
      _activePopup = null;
      _checkPopupQueue();
    });
  }

  void _showRoomInvite(Map<String, dynamic> invite) {
    _activePopup = 'invite';
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      builder: (_) => RoomInviteSheet(invite: invite),
    ).then((accepted) {
      _activePopup = null;
      if (accepted == true && mounted) {
        // Already in chat — the room provider will handle the switch
        return;
      }
      _checkPopupQueue();
    });
  }

  void _checkPopupQueue() {
    if (!mounted || _activePopup != null) return;

    final invites = ref.read(roomInvitesProvider);
    if (invites.isNotEmpty) {
      _showRoomInvite(invites.last);
      return;
    }

    final approval = ref.read(currentApprovalProvider);
    if (approval != null) {
      _showTransferApproval(approval);
      return;
    }

    final clipboard = ref.read(incomingClipboardProvider);
    if (clipboard != null) {
      ref.read(incomingClipboardProvider.notifier).state = null;
      _showClipboardPopup(clipboard);
      return;
    }

    final quickText = ref.read(incomingQuickTextProvider);
    if (quickText != null) {
      ref.read(incomingQuickTextProvider.notifier).state = null;
      _activePopup = 'quickText';
      showDialog(
        context: context,
        builder: (_) => QuickTextPopup(message: quickText),
      ).then((_) {
        _activePopup = null;
        _checkPopupQueue();
      });
    }
  }

  void _confirmLeaveRoom() {
    final s = AppStrings.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.leaveRoom),
        content: Text(s.leaveRoomConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(s.cancel),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(roomProvider.notifier).leaveRoom();
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: Text(s.leaveRoom),
          ),
        ],
      ),
    );
  }
}

class _MemberAvatars extends StatelessWidget {
  final List<RoomMember> members;

  const _MemberAvatars({required this.members});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accepted = members
        .where((m) => m.status == MemberStatus.accepted)
        .take(4)
        .toList();

    return SizedBox(
      width: accepted.length * 22.0 + 10,
      height: 32,
      child: Stack(
        children: [
          for (var i = 0; i < accepted.length; i++)
            Positioned(
              left: i * 22.0,
              child: CircleAvatar(
                radius: 16,
                backgroundColor: _colorForAlias(accepted[i].alias),
                child: Text(
                  accepted[i].alias.isNotEmpty
                      ? accepted[i].alias[0].toUpperCase()
                      : '?',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Color _colorForAlias(String alias) {
    final hash = alias.hashCode;
    final colors = [
      const Color(0xFFE67E22),
      const Color(0xFF2980B9),
      const Color(0xFF27AE60),
      const Color(0xFF8E44AD),
      const Color(0xFFE74C3C),
      const Color(0xFF16A085),
      const Color(0xFFF39C12),
      const Color(0xFF2C3E50),
    ];
    return colors[hash.abs() % colors.length];
  }
}
