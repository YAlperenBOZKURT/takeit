import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import '../../../../core/l10n/app_strings.dart';
import '../../../../core/utils/format_utils.dart';
import '../../../transfer/domain/entities/transfer_session.dart';
import '../../../transfer/presentation/providers/session_transfers_provider.dart';
import '../../domain/entities/message.dart';

class FileBubble extends ConsumerWidget {
  final Message message;
  final bool isMine;

  const FileBubble({super.key, required this.message, required this.isMine});

  void _openFile(BuildContext context) {
    final path = message.savePath;
    if (path == null || path.isEmpty) return;
    final file = File(path);
    if (!file.existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.of(context).fileNotFound)),
      );
      return;
    }
    OpenFilex.open(path);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final fileName = message.fileName ?? 'Unknown file';
    final fileSize = formatFileSize(message.fileSize ?? 0);
    final hasFile = message.savePath != null && message.savePath!.isNotEmpty;

    // Find matching transfer for this message (by fileName + senderId).
    final transfers = ref.watch(sessionTransfersProvider);
    final matching = transfers
        .where(
          (t) =>
              t.session.fileName == message.fileName &&
              t.session.senderId == message.senderId,
        )
        .toList();
    final active = matching.where((t) => t.isActive).firstOrNull;
    final declined = matching
        .where(
          (t) =>
              t.session.status == TransferStatus.declined ||
              t.session.status == TransferStatus.cancelled,
        )
        .firstOrNull;
    final progress = active?.session.progress ?? 0;
    final isDeclined = declined != null && active == null;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        margin: EdgeInsets.only(
          left: isMine ? 48 : 12,
          right: isMine ? 12 : 48,
          top: 4,
          bottom: 4,
        ),
        child: Column(
          crossAxisAlignment: isMine
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            if (!isMine)
              Padding(
                padding: const EdgeInsets.only(left: 12, bottom: 2),
                child: Text(
                  message.senderAlias,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            Opacity(
              opacity: isDeclined ? 0.6 : 1.0,
              child: Material(
                color: isDeclined
                    ? theme.colorScheme.errorContainer.withValues(alpha: 0.5)
                    : isMine
                    ? theme.colorScheme.primaryContainer
                    : theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: (hasFile && active == null && !isDeclined)
                      ? () => _openFile(context)
                      : null,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 40,
                          height: 40,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              if (active != null)
                                SizedBox(
                                  width: 40,
                                  height: 40,
                                  child: CircularProgressIndicator(
                                    value: progress > 0 ? progress : null,
                                    strokeWidth: 3,
                                    color: theme.colorScheme.primary,
                                    backgroundColor:
                                        theme.colorScheme.surfaceContainerHigh,
                                  ),
                                ),
                              Container(
                                width: active != null ? 28 : 40,
                                height: active != null ? 28 : 40,
                                decoration: BoxDecoration(
                                  color: isDeclined
                                      ? theme.colorScheme.error
                                      : _getFileColor(message.fileMimeType),
                                  borderRadius: BorderRadius.circular(
                                    active != null ? 6 : 8,
                                  ),
                                ),
                                child: Icon(
                                  isDeclined
                                      ? Icons.block_rounded
                                      : _getFileIcon(message.fileMimeType),
                                  color: Colors.white,
                                  size: active != null ? 14 : 20,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                fileName,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                isDeclined
                                    ? AppStrings.of(context).fileDeclined
                                    : active != null
                                    ? '${(progress * 100).toStringAsFixed(0)}% · $fileSize'
                                    : fileSize,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: isDeclined
                                      ? theme.colorScheme.error
                                      : theme.colorScheme.onSurfaceVariant,
                                  fontWeight: isDeclined
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                              ),
                            ],
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

  IconData _getFileIcon(String? mimeType) {
    if (mimeType == null) return Icons.insert_drive_file;
    if (mimeType.startsWith('image/')) return Icons.image;
    if (mimeType.startsWith('video/')) return Icons.videocam;
    if (mimeType.startsWith('audio/')) return Icons.audiotrack;
    if (mimeType == 'application/pdf') return Icons.picture_as_pdf;
    return Icons.insert_drive_file;
  }

  Color _getFileColor(String? mimeType) {
    if (mimeType == null) return const Color(0xFF3B424C);
    if (mimeType.startsWith('image/')) return const Color(0xFF27AE60);
    if (mimeType.startsWith('video/')) return const Color(0xFF8E44AD);
    if (mimeType.startsWith('audio/')) return const Color(0xFFE67E22);
    if (mimeType == 'application/pdf') return const Color(0xFFE74C3C);
    return const Color(0xFF3B424C);
  }
}
